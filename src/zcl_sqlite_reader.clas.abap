CLASS zcl_sqlite_reader DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_s_header,
        page_size               TYPE i,
        write_version           TYPE i,
        read_version            TYPE i,
        reserved_bytes_per_page TYPE i,
        usable_page_size        TYPE i,
        database_size_in_pages  TYPE i,
        text_encoding           TYPE i,
        user_version            TYPE i,
        sqlite_version          TYPE i,
      END OF ty_s_header.

    TYPES ty_t_rows TYPE STANDARD TABLE OF REF TO zcl_sqlite_row WITH DEFAULT KEY.

    DATA ms_header  TYPE ty_s_header                    READ-ONLY.
    DATA mt_schemas TYPE zcl_sqlite_types=>ty_t_schemas READ-ONLY.

    METHODS constructor
      IMPORTING iv_path TYPE string
      RAISING   zcx_sqlite_error.

    METHODS read_page
      IMPORTING iv_page          TYPE i
      RETURNING VALUE(rv_buffer) TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS get_page_size
      RETURNING VALUE(rv_size) TYPE i.

    METHODS get_usable_page_size
      RETURNING VALUE(rv_size) TYPE i.

    METHODS get_tables
      RETURNING VALUE(rt_tables) TYPE zcl_sqlite_types=>ty_t_schemas.

    METHODS get_table
      IMPORTING iv_table_name   TYPE string
      RETURNING VALUE(rs_table) TYPE zcl_sqlite_types=>ty_s_schema
      RAISING   zcx_sqlite_error.

    METHODS open_iterator
      IMPORTING iv_table_name TYPE string
      RETURNING VALUE(ro_it)  TYPE REF TO zcl_sqlite_iterator
      RAISING   zcx_sqlite_error.

    METHODS open_page_iterator
      IMPORTING iv_root_page     TYPE i
                it_col_names     TYPE string_table OPTIONAL
                iv_rowid_alias   TYPE i            DEFAULT -1
                iv_without_rowid TYPE abap_bool    DEFAULT abap_false
      RETURNING VALUE(ro_it)     TYPE REF TO zcl_sqlite_iterator
      RAISING   zcx_sqlite_error.

    METHODS scan_table
      IMPORTING iv_table_name  TYPE string
      RETURNING VALUE(rt_rows) TYPE ty_t_rows
      RAISING   zcx_sqlite_error.

  PRIVATE SECTION.
    DATA mv_buffer TYPE xstring.

    TYPES:
      BEGIN OF ty_s_cache,
        page   TYPE i,
        buffer TYPE xstring,
      END OF ty_s_cache.

    DATA mt_cache TYPE HASHED TABLE OF ty_s_cache WITH UNIQUE KEY page.

    METHODS read_file
      IMPORTING iv_path          TYPE string
      RETURNING VALUE(rv_buffer) TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS parse_header
      IMPORTING iv_buffer        TYPE xstring
      RETURNING VALUE(rs_header) TYPE ty_s_header
      RAISING   zcx_sqlite_error.

    METHODS load_schemas
      RAISING zcx_sqlite_error.

    METHODS is_table_schema
      IMPORTING is_schema     TYPE zcl_sqlite_types=>ty_s_schema
      RETURNING VALUE(rv_yes) TYPE abap_bool.

    METHODS find_table_schema
      IMPORTING iv_table_name   TYPE string
      RETURNING VALUE(rs_table) TYPE zcl_sqlite_types=>ty_s_schema
      RAISING   zcx_sqlite_error.
ENDCLASS.


CLASS zcl_sqlite_reader IMPLEMENTATION.
  METHOD constructor.
    DATA lv_header TYPE xstring.

    mv_buffer = read_file( iv_path ).

    IF xstrlen( mv_buffer ) < 100.
      zcx_sqlite_error=>raise( 'SQLite file must be at least 100 bytes long.' ).
    ENDIF.

    lv_header = mv_buffer(100).
    ms_header = parse_header( lv_header ).
    load_schemas( ).
  ENDMETHOD.

  METHOD read_file.
    TYPES ty_t_stream TYPE x LENGTH 1024.
    DATA lt_stream TYPE STANDARD TABLE OF ty_t_stream WITH DEFAULT KEY.

    IF sy-sysid = 'ABC'.
      WRITE '@KERNEL const { readFileSync } = await import(`fs`);'.
      WRITE '@KERNEL const buffer = readFileSync(iv_path.get());'.
      WRITE '@KERNEL rv_buffer.set(buffer.toString(`hex`).toUpperCase());'.
    ELSE.
      CALL METHOD ('CL_GUI_FRONTEND_SERVICES')=>gui_upload
        EXPORTING
          filename = iv_path
          filetype = 'BIN'
        CHANGING
          data_tab = lt_stream
        EXCEPTIONS
          OTHERS   = 1.
      IF sy-subrc <> 0.
        zcx_sqlite_error=>raise_syst( ).
      ENDIF.
      CONCATENATE LINES OF lt_stream INTO rv_buffer IN BYTE MODE.
    ENDIF.
  ENDMETHOD.

  METHOD parse_header.
    IF xstrlen( iv_buffer ) < 100.
      zcx_sqlite_error=>raise( 'SQLite header must be at least 100 bytes long.' ).
    ENDIF.

    IF iv_buffer(16) <> '53514C69746520666F726D6174203300'.
      zcx_sqlite_error=>raise( 'Invalid SQLite header: magic string mismatch.' ).
    ENDIF.

    rs_header-page_size = zcl_sqlite_codec=>read_uint16( iv_buf = iv_buffer
                                                         iv_off = 16 ).
    IF rs_header-page_size = 1.
      rs_header-page_size = 65536.
    ENDIF.

    rs_header-write_version = zcl_sqlite_codec=>read_uint8( iv_buf = iv_buffer
                                                            iv_off = 18 ).
    rs_header-read_version = zcl_sqlite_codec=>read_uint8( iv_buf = iv_buffer
                                                           iv_off = 19 ).
    rs_header-reserved_bytes_per_page = zcl_sqlite_codec=>read_uint8( iv_buf = iv_buffer
                                                                      iv_off = 20 ).
    rs_header-database_size_in_pages = zcl_sqlite_codec=>read_int32( iv_buf = iv_buffer
                                                                     iv_off = 28 ).
    rs_header-text_encoding = zcl_sqlite_codec=>read_int32( iv_buf = iv_buffer
                                                            iv_off = 56 ).
    rs_header-user_version = zcl_sqlite_codec=>read_int32( iv_buf = iv_buffer
                                                           iv_off = 60 ).
    rs_header-sqlite_version = zcl_sqlite_codec=>read_int32( iv_buf = iv_buffer
                                                             iv_off = 96 ).
    rs_header-usable_page_size = rs_header-page_size - rs_header-reserved_bytes_per_page.
  ENDMETHOD.

  METHOD read_page.
    DATA ls_cache TYPE ty_s_cache.
    DATA lv_off   TYPE int8.

    IF iv_page < 1.
      zcx_sqlite_error=>raise( 'SQLite page numbers are 1-based.' ).
    ENDIF.

    READ TABLE mt_cache INTO ls_cache WITH TABLE KEY page = iv_page.
    IF sy-subrc = 0.
      rv_buffer = ls_cache-buffer.
      RETURN.
    ENDIF.

    lv_off = ( iv_page - 1 ) * ms_header-page_size.
    IF lv_off + ms_header-page_size > xstrlen( mv_buffer ).
      zcx_sqlite_error=>raise( |Requested page { iv_page } is beyond the end of the file.| ).
    ENDIF.

    rv_buffer = mv_buffer+lv_off(ms_header-page_size).

    ls_cache-page = iv_page.
    ls_cache-buffer = rv_buffer.
    INSERT ls_cache INTO TABLE mt_cache.
  ENDMETHOD.

  METHOD get_page_size.
    rv_size = ms_header-page_size.
  ENDMETHOD.

  METHOD get_usable_page_size.
    rv_size = ms_header-usable_page_size.
  ENDMETHOD.

  METHOD is_table_schema.
    rv_yes = boolc( to_upper( is_schema-type ) = 'TABLE' ).
  ENDMETHOD.

  METHOD get_tables.
    DATA ls_schema LIKE LINE OF mt_schemas.

    LOOP AT mt_schemas INTO ls_schema.
      IF is_table_schema( ls_schema ) = abap_true.
        INSERT ls_schema INTO TABLE rt_tables.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD find_table_schema.
    DATA lv_target TYPE string.
    DATA ls_schema LIKE LINE OF mt_schemas.

    lv_target = to_upper( iv_table_name ).

    LOOP AT mt_schemas INTO ls_schema.
      IF is_table_schema( ls_schema ) = abap_true AND to_upper( ls_schema-name ) = lv_target.
        rs_table = ls_schema.
        RETURN.
      ENDIF.
    ENDLOOP.

    zcx_sqlite_error=>raise( |Table '{ iv_table_name }' not found| ).
  ENDMETHOD.

  METHOD get_table.
    rs_table = find_table_schema( iv_table_name ).
  ENDMETHOD.

  METHOD load_schemas.
    DATA lt_cols  TYPE string_table.
    DATA ls_schema TYPE zcl_sqlite_types=>ty_s_schema.
    DATA lo_it    TYPE REF TO zcl_sqlite_iterator.
    DATA lo_row   TYPE REF TO zcl_sqlite_row.
    DATA ls_val   TYPE zcl_sqlite_types=>ty_s_value.

    INSERT `type` INTO TABLE lt_cols.
    INSERT `name` INTO TABLE lt_cols.
    INSERT `tbl_name` INTO TABLE lt_cols.
    INSERT `rootpage` INTO TABLE lt_cols.
    INSERT `sql` INTO TABLE lt_cols.

    CREATE OBJECT lo_it
      EXPORTING
        io_reader            = me
        iv_root_page         = 1
        it_col_names         = lt_cols
        iv_rowid_alias_index = -1
        iv_without_rowid     = abap_false.

    WHILE lo_it->has_next( ) = abap_true.
      lo_row = lo_it->next( ).

      ls_val = lo_row->get_value_by_name( 'type' ).
      ls_schema-type = ls_val-text_value.

      ls_val = lo_row->get_value_by_name( 'name' ).
      ls_schema-name = ls_val-text_value.

      ls_val = lo_row->get_value_by_name( 'tbl_name' ).
      ls_schema-tbl_name = ls_val-text_value.

      ls_val = lo_row->get_value_by_name( 'rootpage' ).
      ls_schema-rootpage = ls_val-integer_value.

      ls_val = lo_row->get_value_by_name( 'sql' ).
      ls_schema-sql = ls_val-text_value.
      ls_schema-column_names = zcl_sqlite_schema_parser=>extract_column_names( ls_schema-sql ).
      ls_schema-rowid_alias_index = zcl_sqlite_schema_parser=>get_rowid_alias_index( ls_schema-sql ).
      ls_schema-has_rowid_alias = boolc( ls_schema-rowid_alias_index >= 0 ).
      ls_schema-is_without_rowid = zcl_sqlite_schema_parser=>is_without_rowid( ls_schema-sql ).

      INSERT ls_schema INTO TABLE mt_schemas.
    ENDWHILE.
  ENDMETHOD.

  METHOD open_iterator.
    DATA ls_table TYPE zcl_sqlite_types=>ty_s_schema.

    ls_table = get_table( iv_table_name ).

    CREATE OBJECT ro_it
      EXPORTING
        io_reader            = me
        iv_root_page         = ls_table-rootpage
        it_col_names         = ls_table-column_names
        iv_rowid_alias_index = ls_table-rowid_alias_index
        iv_without_rowid     = ls_table-is_without_rowid.
  ENDMETHOD.

  METHOD open_page_iterator.
    CREATE OBJECT ro_it
      EXPORTING
        io_reader            = me
        iv_root_page         = iv_root_page
        it_col_names         = it_col_names
        iv_rowid_alias_index = iv_rowid_alias
        iv_without_rowid     = iv_without_rowid.
  ENDMETHOD.

  METHOD scan_table.
    DATA lo_it  TYPE REF TO zcl_sqlite_iterator.
    DATA lo_row TYPE REF TO zcl_sqlite_row.

    lo_it = open_iterator( iv_table_name ).

    WHILE lo_it->has_next( ) = abap_true.
      lo_row = lo_it->next( ).
      INSERT lo_row INTO TABLE rt_rows.
    ENDWHILE.
  ENDMETHOD.
ENDCLASS.
