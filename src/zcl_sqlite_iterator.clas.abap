CLASS zcl_sqlite_iterator DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING io_reader            TYPE REF TO zcl_sqlite_reader
                iv_root_page         TYPE i
                it_col_names         TYPE string_table OPTIONAL
                iv_rowid_alias_index TYPE i            DEFAULT -1
                iv_without_rowid     TYPE abap_bool    DEFAULT abap_false
      RAISING   zcx_sqlite_error.

    METHODS has_next
      RETURNING VALUE(rv_has) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS next
      RETURNING VALUE(ro_row) TYPE REF TO zcl_sqlite_row
      RAISING   zcx_sqlite_error.

  PRIVATE SECTION.
    DATA mo_reader        TYPE REF TO zcl_sqlite_reader.
    DATA mt_col_names     TYPE string_table.
    DATA mv_rowid_alias   TYPE i.
    DATA mv_without_rowid TYPE abap_bool.
    DATA mt_stack         TYPE STANDARD TABLE OF zcl_sqlite_btree_page=>ty_s_frame WITH DEFAULT KEY.
    DATA mo_cached        TYPE REF TO zcl_sqlite_row.
    DATA mv_has_cached    TYPE abap_bool.

    METHODS push_frame
      IMPORTING iv_page_no TYPE i
      RAISING   zcx_sqlite_error.

    METHODS fetch_next
      RETURNING VALUE(ro_row) TYPE REF TO zcl_sqlite_row
      RAISING   zcx_sqlite_error.

    METHODS handle_leaf
      IMPORTING iv_idx         TYPE i
      RETURNING VALUE(ro_row)  TYPE REF TO zcl_sqlite_row
      RAISING   zcx_sqlite_error.

    METHODS handle_interior
      IMPORTING iv_idx TYPE i
      RAISING   zcx_sqlite_error.

    METHODS read_leaf_row
      IMPORTING iv_page_no     TYPE i
                iv_cell_offset TYPE i
                iv_page_type   TYPE i
      RETURNING VALUE(ro_row)  TYPE REF TO zcl_sqlite_row
      RAISING   zcx_sqlite_error.
ENDCLASS.


CLASS zcl_sqlite_iterator IMPLEMENTATION.
  METHOD constructor.
    mo_reader = io_reader.
    mt_col_names = it_col_names.
    mv_rowid_alias = iv_rowid_alias_index.
    mv_without_rowid = iv_without_rowid.
    mv_has_cached = abap_false.
    push_frame( iv_root_page ).
  ENDMETHOD.

  METHOD has_next.
    IF mv_has_cached = abap_true.
      rv_has = abap_true.
      RETURN.
    ENDIF.

    mo_cached = fetch_next( ).
    IF mo_cached IS BOUND.
      mv_has_cached = abap_true.
      rv_has = abap_true.
    ELSE.
      mv_has_cached = abap_false.
      rv_has = abap_false.
    ENDIF.
  ENDMETHOD.

  METHOD next.
    IF has_next( ) = abap_false.
      zcx_sqlite_error=>raise( 'No more rows' ).
    ENDIF.
    mv_has_cached = abap_false.
    ro_row = mo_cached.
  ENDMETHOD.

  METHOD push_frame.
    DATA lv_buf  TYPE xstring.
    DATA ls_frame TYPE zcl_sqlite_btree_page=>ty_s_frame.

    lv_buf = mo_reader->read_page( iv_page_no ).
    ls_frame = zcl_sqlite_btree_page=>parse( iv_page_no = iv_page_no
                                             iv_buffer  = lv_buf ).
    INSERT ls_frame INTO TABLE mt_stack.
  ENDMETHOD.

  METHOD fetch_next.
    DATA lv_top TYPE i.
    FIELD-SYMBOLS <ls_frame> TYPE zcl_sqlite_btree_page=>ty_s_frame.

    WHILE lines( mt_stack ) > 0.
      lv_top = lines( mt_stack ).
      READ TABLE mt_stack INDEX lv_top ASSIGNING <ls_frame>.
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.

      IF zcl_sqlite_btree_page=>is_leaf( <ls_frame>-page_type ) = abap_true.
        ro_row = handle_leaf( lv_top ).
        IF ro_row IS BOUND.
          RETURN.
        ENDIF.
        CONTINUE.
      ENDIF.

      IF zcl_sqlite_btree_page=>is_interior( <ls_frame>-page_type ) = abap_true.
        handle_interior( lv_top ).
        CONTINUE.
      ENDIF.

      zcx_sqlite_error=>raise( |Page type { <ls_frame>-page_type } not supported| ).
    ENDWHILE.
  ENDMETHOD.

  METHOD handle_leaf.
    FIELD-SYMBOLS <ls_frame> TYPE zcl_sqlite_btree_page=>ty_s_frame.
    DATA lv_idx TYPE i.
    DATA lv_off TYPE i.

    READ TABLE mt_stack INDEX iv_idx ASSIGNING <ls_frame>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF <ls_frame>-next_idx >= <ls_frame>-cell_count.
      DELETE mt_stack INDEX iv_idx.
      RETURN.
    ENDIF.

    lv_idx = <ls_frame>-next_idx + 1.
    READ TABLE <ls_frame>-cell_offsets INDEX lv_idx INTO lv_off.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    <ls_frame>-next_idx = <ls_frame>-next_idx + 1.
    ro_row = read_leaf_row( iv_page_no     = <ls_frame>-page_no
                            iv_cell_offset = lv_off
                            iv_page_type   = <ls_frame>-page_type ).
  ENDMETHOD.

  METHOD handle_interior.
    FIELD-SYMBOLS <ls_frame> TYPE zcl_sqlite_btree_page=>ty_s_frame.
    DATA lv_idx TYPE i.
    DATA lv_child TYPE i.

    READ TABLE mt_stack INDEX iv_idx ASSIGNING <ls_frame>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF <ls_frame>-next_idx < <ls_frame>-cell_count.
      lv_idx = <ls_frame>-next_idx + 1.
      READ TABLE <ls_frame>-left_children INDEX lv_idx INTO lv_child.
      IF sy-subrc = 0.
        <ls_frame>-next_idx = <ls_frame>-next_idx + 1.
        push_frame( lv_child ).
        RETURN.
      ENDIF.
    ENDIF.

    IF <ls_frame>-next_idx = <ls_frame>-cell_count.
      <ls_frame>-next_idx = <ls_frame>-next_idx + 1.
      push_frame( <ls_frame>-right_child ).
      RETURN.
    ENDIF.

    DELETE mt_stack INDEX iv_idx.
  ENDMETHOD.

  METHOD read_leaf_row.
    DATA lv_mem     TYPE xstring.
    DATA lv_cur     TYPE i.
    DATA lv_rowid   TYPE int8.
    DATA lv_payload TYPE xstring.
    DATA lv_alias   TYPE i.
    DATA lv_size    TYPE int8.
    DATA lv_n1      TYPE i.
    DATA lv_n2      TYPE i.
    DATA lv_local   TYPE i.
    DATA lv_cell    TYPE xstring.
    DATA lv_ptr     TYPE i.

    lv_mem = mo_reader->read_page( iv_page_no ).
    lv_cur = iv_cell_offset.

    zcl_sqlite_varint=>decode( EXPORTING iv_buffer     = lv_mem
                                         iv_offset     = lv_cur
                               IMPORTING ev_value      = lv_size
                                         ev_bytes_read = lv_n1 ).
    lv_cur = lv_cur + lv_n1.

    IF iv_page_type = zcl_sqlite_btree_page=>c_leaf_table.
      zcl_sqlite_varint=>decode( EXPORTING iv_buffer     = lv_mem
                                           iv_offset     = lv_cur
                                 IMPORTING ev_value      = lv_rowid
                                           ev_bytes_read = lv_n2 ).
      lv_cur = lv_cur + lv_n2.
    ENDIF.

    lv_local = zcl_sqlite_overflow_handler=>calc_local_size(
                 iv_payload_size = lv_size
                 iv_usable_size  = mo_reader->get_usable_page_size( ) ).
    lv_cell = lv_mem+lv_cur(lv_local).

    IF lv_size = lv_local.
      lv_payload = lv_cell.
    ELSE.
      lv_ptr = lv_cur + lv_local.
      lv_payload = zcl_sqlite_overflow_handler=>reassemble(
                     io_reader       = mo_reader
                     iv_cell_payload = lv_cell
                     iv_payload_size = lv_size
                     iv_local_size   = lv_local
                     iv_overflow_ptr = lv_ptr
                     iv_cell_buffer  = lv_mem ).
    ENDIF.

    IF iv_page_type <> zcl_sqlite_btree_page=>c_leaf_index AND mv_without_rowid = abap_false.
      lv_alias = mv_rowid_alias.
    ELSE.
      lv_alias = -1.
    ENDIF.

    ro_row = zcl_sqlite_record_decoder=>decode( iv_rowid     = lv_rowid
                                                iv_payload   = lv_payload
                                                it_col_names = mt_col_names
                                                iv_alias     = lv_alias ).
  ENDMETHOD.
ENDCLASS.
