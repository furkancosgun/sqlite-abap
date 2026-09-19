CLASS zcl_sqlite_btree_page DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_t_offsets TYPE STANDARD TABLE OF i WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_frame,
        page_no       TYPE i,
        page_type     TYPE i,
        cell_count    TYPE i,
        next_idx      TYPE i,
        right_child   TYPE i,
        cell_offsets  TYPE ty_t_offsets,
        left_children TYPE ty_t_offsets,
      END OF ty_s_frame.

    CONSTANTS:
      c_leaf_table     TYPE i VALUE 13,
      c_leaf_index     TYPE i VALUE 10,
      c_interior_table TYPE i VALUE 5,
      c_interior_index TYPE i VALUE 2.

    CLASS-METHODS parse
      IMPORTING iv_page_no      TYPE i
                iv_buffer       TYPE xstring
      RETURNING VALUE(rs_frame) TYPE ty_s_frame
      RAISING   zcx_sqlite_error.

    CLASS-METHODS is_leaf
      IMPORTING iv_page_type  TYPE i
      RETURNING VALUE(rv_yes) TYPE abap_bool.

    CLASS-METHODS is_interior
      IMPORTING iv_page_type  TYPE i
      RETURNING VALUE(rv_yes) TYPE abap_bool.

  PRIVATE SECTION.
    CLASS-METHODS get_header_offset
      IMPORTING iv_page_no    TYPE i
      RETURNING VALUE(rv_off) TYPE i.

    CLASS-METHODS read_cell_offsets
      IMPORTING iv_buffer      TYPE xstring
                iv_hdr         TYPE i
                iv_cell_count  TYPE i
                iv_start_off   TYPE i
      RETURNING VALUE(rt_offs) TYPE ty_t_offsets.
ENDCLASS.


CLASS zcl_sqlite_btree_page IMPLEMENTATION.
  METHOD get_header_offset.
    IF iv_page_no = 1.
      rv_off = 100.
    ELSE.
      rv_off = 0.
    ENDIF.
  ENDMETHOD.

  METHOD is_leaf.
    rv_yes = boolc( iv_page_type = c_leaf_table OR iv_page_type = c_leaf_index ).
  ENDMETHOD.

  METHOD is_interior.
    rv_yes = boolc( iv_page_type = c_interior_table OR iv_page_type = c_interior_index ).
  ENDMETHOD.

  METHOD read_cell_offsets.
    DATA lv_i   TYPE i.
    DATA lv_ptr TYPE i.
    DATA lv_off TYPE i.

    lv_i = 0.
    WHILE lv_i < iv_cell_count.
      lv_ptr = iv_hdr + iv_start_off + ( lv_i * 2 ).
      lv_off = zcl_sqlite_codec=>read_uint16( iv_buf = iv_buffer
                                              iv_off = lv_ptr ).
      INSERT lv_off INTO TABLE rt_offs.
      lv_i = lv_i + 1.
    ENDWHILE.
  ENDMETHOD.

  METHOD parse.
    DATA lv_mem   TYPE xstring.
    DATA lv_hdr   TYPE i.
    DATA lv_pt    TYPE i.
    DATA lv_cc    TYPE i.
    DATA lv_i     TYPE i.
    DATA lv_off   TYPE i.
    DATA lv_child TYPE i.

    lv_mem = iv_buffer.
    lv_hdr = get_header_offset( iv_page_no ).
    lv_pt = zcl_sqlite_codec=>read_uint8( iv_buf = lv_mem
                                          iv_off = lv_hdr ).
    lv_cc = zcl_sqlite_codec=>read_uint16( iv_buf = lv_mem
                                           iv_off = lv_hdr + 3 ).

    rs_frame-page_no = iv_page_no.
    rs_frame-page_type = lv_pt.
    rs_frame-cell_count = lv_cc.
    rs_frame-next_idx = 0.

    IF is_leaf( lv_pt ) = abap_true.
      rs_frame-cell_offsets = read_cell_offsets( iv_buffer     = lv_mem
                                                 iv_hdr        = lv_hdr
                                                 iv_cell_count = lv_cc
                                                 iv_start_off  = 8 ).
    ELSEIF is_interior( lv_pt ) = abap_true.
      rs_frame-right_child = zcl_sqlite_codec=>read_int32( iv_buf = lv_mem
                                                           iv_off = lv_hdr + 8 ).
      rs_frame-cell_offsets = read_cell_offsets( iv_buffer     = lv_mem
                                                 iv_hdr        = lv_hdr
                                                 iv_cell_count = lv_cc
                                                 iv_start_off  = 12 ).
      lv_i = 0.
      WHILE lv_i < lv_cc.
        READ TABLE rs_frame-cell_offsets INDEX lv_i + 1 INTO lv_off.
        IF sy-subrc = 0.
          lv_child = zcl_sqlite_codec=>read_int32( iv_buf = lv_mem
                                                   iv_off = lv_off ).
          INSERT lv_child INTO TABLE rs_frame-left_children.
        ENDIF.
        lv_i = lv_i + 1.
      ENDWHILE.
    ELSE.
      zcx_sqlite_error=>raise( |B-Tree page type { lv_pt } on page { iv_page_no } not supported| ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
