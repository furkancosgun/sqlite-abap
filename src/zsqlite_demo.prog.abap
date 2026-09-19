*&---------------------------------------------------------------------*
*& Report ZSQLITE_DEMO
*&---------------------------------------------------------------------*
*& SQLite Reader Demonstration in pure ABAP
*&---------------------------------------------------------------------*
REPORT zsqlite_demo.

CLASS lcl_demo DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS run.

  PRIVATE SECTION.
    CLASS-METHODS print_table_preview
      IMPORTING io_reader     TYPE REF TO zcl_sqlite_reader
                iv_table_name TYPE string
                iv_max_rows   TYPE i.
ENDCLASS.

CLASS lcl_demo IMPLEMENTATION.
  METHOD run.
    DATA lo_reader TYPE REF TO zcl_sqlite_reader.
    DATA lt_tables TYPE zcl_sqlite_types=>ty_t_schemas.
    DATA ls_tab    TYPE zcl_sqlite_types=>ty_s_schema.
    DATA lv_cols   TYPE string.
    DATA lx_ex     TYPE REF TO zcx_sqlite_error.

    TRY.
        CREATE OBJECT lo_reader
          EXPORTING
            iv_path = 'sample.db'.

        WRITE / '=================================================================='.
        WRITE / '       Pure ABAP SQLite Reader - Demonstration                    '.
        WRITE / '=================================================================='.
        WRITE / '[+] Database Opened Successfully'.
        WRITE / |   * Page Size: { lo_reader->ms_header-page_size } bytes|.
        WRITE / |   * Usable Page Size: { lo_reader->ms_header-usable_page_size } bytes|.
        WRITE / |   * Total Page Count: { lo_reader->ms_header-database_size_in_pages }|.
        WRITE / |   * SQLite Version: { lo_reader->ms_header-sqlite_version }|.

        WRITE / '[+] Discovered Tables (sqlite_schema / Master Table - Page 1):'.
        lt_tables = lo_reader->get_tables( ).
        LOOP AT lt_tables INTO ls_tab.
          lv_cols = concat_lines_of( table = ls_tab-column_names
                                     sep   = ', ' ).
          IF lv_cols IS INITIAL.
            lv_cols = '(No columns parsed)'.
          ENDIF.
          WRITE / |   -> Table: { ls_tab-name } \| RootPage: { ls_tab-rootpage } \| Columns: [{ lv_cols }]|.
          print_table_preview( io_reader     = lo_reader
                               iv_table_name = ls_tab-tbl_name
                               iv_max_rows   = 10 ).
        ENDLOOP.

        WRITE / '[OK] SQLite database scanned successfully with Pure ABAP B-Tree & Record Parser!'.
      CATCH zcx_sqlite_error INTO lx_ex.
        WRITE / |[!] Error: { lx_ex->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

  METHOD print_table_preview.
    DATA ls_schema    TYPE zcl_sqlite_types=>ty_s_schema.
    DATA lo_it        TYPE REF TO zcl_sqlite_iterator.
    DATA lo_row       TYPE REF TO zcl_sqlite_row.
    DATA ls_col       TYPE zcl_sqlite_types=>ty_s_column.
    DATA lv_count     TYPE i.
    DATA lv_val_str   TYPE string.
    DATA lv_remaining TYPE i.
    DATA lx_err       TYPE REF TO zcx_sqlite_error.
    DATA lv_len       TYPE i.
    DATA lv_trunc     TYPE string.
    DATA lv_msg       TYPE string.

    lv_count = 0.

    TRY.
        ls_schema = io_reader->get_table( iv_table_name ).
        WRITE / '========================================================'.
        WRITE / |[*] SCANNING TABLE: { ls_schema-name } (RootPage: { ls_schema-rootpage })|.
        WRITE / |    withoutRowId = { ls_schema-is_without_rowid }|.
        WRITE / '========================================================'.

        lo_it = io_reader->open_iterator( iv_table_name ).

        WHILE lo_it->has_next( ) = abap_true.
          lo_row = lo_it->next( ).
          lv_count = lv_count + 1.

          WRITE / |-> RowID: { lo_row->mv_rowid }|.
          LOOP AT lo_row->mt_columns INTO ls_col.
            lv_val_str = zcl_sqlite_types=>value_to_string( ls_col-value ).
            lv_len = strlen( lv_val_str ).
            IF lv_len > 60.
              lv_trunc = substring( val = lv_val_str
                                    off = 0
                                    len = 57 ).
              lv_val_str = |{ lv_trunc }...|.
            ENDIF.
            WRITE / |   { ls_col-name } [{ ls_col-value-data_type }] = { lv_val_str }|.
          ENDLOOP.

          IF lv_count >= iv_max_rows.
            lv_remaining = lv_count.
            WHILE lo_it->has_next( ) = abap_true.
              lo_it->next( ).
              lv_remaining = lv_remaining + 1.
            ENDWHILE.
            WRITE / |   ... ({ lv_count } shown, total { lv_remaining } rows)|.
            EXIT.
          ENDIF.
        ENDWHILE.

        IF lv_count = 0.
          WRITE / '   (Table is empty)'.
        ENDIF.
      CATCH zcx_sqlite_error INTO lx_err.
        lv_msg = lx_err->get_text( ).
        WRITE / |[-] Error: { lv_msg }|.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  lcl_demo=>run( ).
