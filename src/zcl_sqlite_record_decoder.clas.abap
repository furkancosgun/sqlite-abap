CLASS zcl_sqlite_record_decoder DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_t_serials TYPE STANDARD TABLE OF int8 WITH DEFAULT KEY.

    CLASS-METHODS decode
      IMPORTING iv_rowid      TYPE int8
                iv_payload    TYPE xstring
                it_col_names  TYPE string_table
                iv_alias      TYPE i
      RETURNING VALUE(ro_row) TYPE REF TO zcl_sqlite_row
      RAISING   zcx_sqlite_error.

  PRIVATE SECTION.
    CLASS-METHODS parse_header
      IMPORTING iv_payload     TYPE xstring
      EXPORTING ev_header_size TYPE i
                et_serials     TYPE ty_t_serials
      RAISING   zcx_sqlite_error.

    CLASS-METHODS build_row_with_alias
      IMPORTING iv_rowid      TYPE int8
                iv_payload    TYPE xstring
                it_col_names  TYPE string_table
                iv_alias      TYPE i
                it_serials    TYPE ty_t_serials
                iv_header_end TYPE i
      RETURNING VALUE(ro_row) TYPE REF TO zcl_sqlite_row
      RAISING   zcx_sqlite_error.

    CLASS-METHODS build_row_generic
      IMPORTING iv_rowid      TYPE int8
                iv_payload    TYPE xstring
                it_col_names  TYPE string_table
                iv_alias      TYPE i
                it_serials    TYPE ty_t_serials
                iv_header_end TYPE i
      RETURNING VALUE(ro_row) TYPE REF TO zcl_sqlite_row
      RAISING   zcx_sqlite_error.

    CLASS-METHODS decode_value
      IMPORTING iv_serial   TYPE int8
                iv_buf      TYPE xstring
                iv_off      TYPE i
      EXPORTING es_value    TYPE zcl_sqlite_types=>ty_s_value
                ev_consumed TYPE i
      RAISING   zcx_sqlite_error.
ENDCLASS.


CLASS zcl_sqlite_record_decoder IMPLEMENTATION.
  METHOD decode.
    DATA lt_serials    TYPE ty_t_serials.
    DATA lv_hdr_end    TYPE i.
    DATA lv_col_count  TYPE i.
    DATA lv_has_alias  TYPE abap_bool.
    DATA lv_serial_cnt TYPE i.
    DATA lv_expected   TYPE i.
    DATA lt_empty TYPE zcl_sqlite_types=>ty_t_columns.

    IF xstrlen( iv_payload ) = 0.

      CREATE OBJECT ro_row
        EXPORTING
          iv_rowid   = iv_rowid
          it_columns = lt_empty.
      RETURN.
    ENDIF.

    parse_header( EXPORTING iv_payload     = iv_payload
                  IMPORTING ev_header_size = lv_hdr_end
                            et_serials     = lt_serials ).

    lv_col_count = lines( it_col_names ).
    lv_has_alias = boolc( iv_alias >= 0 AND iv_alias < lv_col_count ).

    lv_serial_cnt = lines( lt_serials ).
    lv_expected = lv_col_count - 1.
    IF lv_has_alias = abap_true.
      IF lv_serial_cnt = lv_expected.
        ro_row = build_row_with_alias( iv_rowid      = iv_rowid
                                       iv_payload    = iv_payload
                                       it_col_names  = it_col_names
                                       iv_alias      = iv_alias
                                       it_serials    = lt_serials
                                       iv_header_end = lv_hdr_end ).
      ELSE.
        ro_row = build_row_generic( iv_rowid      = iv_rowid
                                    iv_payload    = iv_payload
                                    it_col_names  = it_col_names
                                    iv_alias      = iv_alias
                                    it_serials    = lt_serials
                                    iv_header_end = lv_hdr_end ).
      ENDIF.
    ELSE.
      ro_row = build_row_generic( iv_rowid      = iv_rowid
                                  iv_payload    = iv_payload
                                  it_col_names  = it_col_names
                                  iv_alias      = iv_alias
                                  it_serials    = lt_serials
                                  iv_header_end = lv_hdr_end ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_header.
    DATA lv_hdr_size    TYPE int8.
    DATA lv_n0          TYPE i.
    DATA lv_cur         TYPE i.
    DATA lv_sv          TYPE int8.
    DATA lv_n           TYPE i.
    DATA lv_payload_len TYPE i.

    zcl_sqlite_varint=>decode( EXPORTING iv_buffer     = iv_payload
                                         iv_offset     = 0
                               IMPORTING ev_value      = lv_hdr_size
                                         ev_bytes_read = lv_n0 ).

    ev_header_size = lv_hdr_size.
    lv_cur = lv_n0.
    lv_payload_len = xstrlen( iv_payload ).

    WHILE lv_cur < ev_header_size AND lv_cur < lv_payload_len.
      zcl_sqlite_varint=>decode( EXPORTING iv_buffer     = iv_payload
                                           iv_offset     = lv_cur
                                 IMPORTING ev_value      = lv_sv
                                           ev_bytes_read = lv_n ).
      INSERT lv_sv INTO TABLE et_serials.
      lv_cur = lv_cur + lv_n.
    ENDWHILE.
  ENDMETHOD.

  METHOD build_row_with_alias.
    DATA lt_cols        TYPE zcl_sqlite_types=>ty_t_columns.
    DATA lv_name        TYPE string.
    DATA lv_body_off    TYPE i.
    DATA lv_si          TYPE i.
    DATA lv_ci          TYPE i.
    DATA ls_col         TYPE zcl_sqlite_types=>ty_s_column.
    DATA lv_curr_serial TYPE int8.
    DATA ls_dec_val     TYPE zcl_sqlite_types=>ty_s_value.
    DATA lv_c           TYPE i.
    DATA lv_col_cnt     TYPE i.

    lv_body_off = iv_header_end.
    lv_si = 1.
    lv_ci = 0.
    lv_col_cnt = lines( it_col_names ).

    WHILE lv_ci < lv_col_cnt.
      READ TABLE it_col_names INDEX lv_ci + 1 INTO lv_name.
      IF sy-subrc <> 0.
        CLEAR lv_name.
      ENDIF.
      CLEAR ls_col.
      ls_col-index = lv_ci.
      ls_col-name = lv_name.

      IF lv_ci = iv_alias.
        ls_col-value = zcl_sqlite_types=>value_from_integer( iv_rowid ).
      ELSE.
        READ TABLE it_serials INDEX lv_si INTO lv_curr_serial.
        IF sy-subrc = 0.
          decode_value( EXPORTING iv_serial   = lv_curr_serial
                                  iv_buf      = iv_payload
                                  iv_off      = lv_body_off
                        IMPORTING es_value    = ls_dec_val
                                  ev_consumed = lv_c ).
          ls_col-value = ls_dec_val.
          lv_body_off = lv_body_off + lv_c.
          lv_si = lv_si + 1.
        ENDIF.
      ENDIF.
      INSERT ls_col INTO TABLE lt_cols.
      lv_ci = lv_ci + 1.
    ENDWHILE.

    CREATE OBJECT ro_row
      EXPORTING
        iv_rowid   = iv_rowid
        it_columns = lt_cols.
  ENDMETHOD.

  METHOD build_row_generic.
    DATA lt_out_cols  TYPE zcl_sqlite_types=>ty_t_columns.
    DATA lv_name      TYPE string.
    DATA lv_body      TYPE i.
    DATA lv_idx       TYPE i.
    DATA ls_col       TYPE zcl_sqlite_types=>ty_s_column.
    DATA ls_v         TYPE zcl_sqlite_types=>ty_s_value.
    DATA lv_consumed  TYPE i.
    DATA lv_serial    TYPE int8.
    DATA lv_has_alias TYPE abap_bool.
    DATA lv_col_cnt   TYPE i.

    lv_col_cnt = lines( it_col_names ).
    lv_has_alias = boolc( iv_alias >= 0 AND iv_alias < lv_col_cnt ).
    lv_body = iv_header_end.
    lv_idx = 0.

    LOOP AT it_serials INTO lv_serial.
      IF lv_idx < lv_col_cnt.
        READ TABLE it_col_names INDEX lv_idx + 1 INTO lv_name.
        IF sy-subrc <> 0.
          CLEAR lv_name.
        ENDIF.
      ELSE.
        lv_name = |Col_{ lv_idx }|.
      ENDIF.

      decode_value( EXPORTING iv_serial   = lv_serial
                              iv_buf      = iv_payload
                              iv_off      = lv_body
                    IMPORTING es_value    = ls_v
                              ev_consumed = lv_consumed ).

      IF lv_has_alias = abap_true AND lv_idx = iv_alias.
        ls_v = zcl_sqlite_types=>value_from_integer( iv_rowid ).
      ENDIF.

      CLEAR ls_col.
      ls_col-index = lv_idx.
      ls_col-name = lv_name.
      ls_col-value = ls_v.
      INSERT ls_col INTO TABLE lt_out_cols.

      lv_body = lv_body + lv_consumed.
      lv_idx = lv_idx + 1.
    ENDLOOP.

    CREATE OBJECT ro_row
      EXPORTING
        iv_rowid   = iv_rowid
        it_columns = lt_out_cols.
  ENDMETHOD.

  METHOD decode_value.
    DATA lv_blen TYPE i.
    DATA lv_tlen TYPE i.
    DATA lv_mod2 TYPE i.

    ev_consumed = 0.

    CASE iv_serial.
      WHEN 0.
        es_value = zcl_sqlite_types=>value_null( ).
      WHEN 1.
        es_value = zcl_sqlite_types=>value_from_integer( zcl_sqlite_codec=>read_int8_val( iv_buf = iv_buf
                                                                                          iv_off = iv_off ) ).
        ev_consumed = 1.
      WHEN 2.
        es_value = zcl_sqlite_types=>value_from_integer( zcl_sqlite_codec=>read_int16( iv_buf = iv_buf
                                                                                       iv_off = iv_off ) ).
        ev_consumed = 2.
      WHEN 3.
        es_value = zcl_sqlite_types=>value_from_integer( zcl_sqlite_codec=>read_int24( iv_buf = iv_buf
                                                                                       iv_off = iv_off ) ).
        ev_consumed = 3.
      WHEN 4.
        es_value = zcl_sqlite_types=>value_from_integer( zcl_sqlite_codec=>read_int32( iv_buf = iv_buf
                                                                                       iv_off = iv_off ) ).
        ev_consumed = 4.
      WHEN 5.
        es_value = zcl_sqlite_types=>value_from_integer( zcl_sqlite_codec=>read_int48( iv_buf = iv_buf
                                                                                       iv_off = iv_off ) ).
        ev_consumed = 6.
      WHEN 6.
        es_value = zcl_sqlite_types=>value_from_integer( zcl_sqlite_codec=>read_int64( iv_buf = iv_buf
                                                                                       iv_off = iv_off ) ).
        ev_consumed = 8.
      WHEN 7.
        es_value = zcl_sqlite_types=>value_from_real( zcl_sqlite_codec=>read_double( iv_buf = iv_buf
                                                                                     iv_off = iv_off ) ).
        ev_consumed = 8.
      WHEN 8.
        es_value = zcl_sqlite_types=>value_from_integer( 0 ).
      WHEN 9.
        es_value = zcl_sqlite_types=>value_from_integer( 1 ).
      WHEN 10 OR 11.
        es_value = zcl_sqlite_types=>value_null( ).
      WHEN OTHERS.
        lv_mod2 = iv_serial MOD 2.
        IF iv_serial >= 12 AND lv_mod2 = 0.
          lv_blen = ( iv_serial - 12 ) / 2.
          es_value = zcl_sqlite_types=>value_from_blob( zcl_sqlite_codec=>read_bytes( iv_buf = iv_buf
                                                                                      iv_off = iv_off
                                                                                      iv_len = lv_blen ) ).
          ev_consumed = lv_blen.
        ELSEIF iv_serial >= 13 AND lv_mod2 = 1.
          lv_tlen = ( iv_serial - 13 ) / 2.
          es_value = zcl_sqlite_types=>value_from_text( zcl_sqlite_codec=>read_text( iv_buf = iv_buf
                                                                                     iv_off = iv_off
                                                                                     iv_len = lv_tlen ) ).
          ev_consumed = lv_tlen.
        ELSE.
          zcx_sqlite_error=>raise( |Invalid serial type { iv_serial }| ).
        ENDIF.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.
