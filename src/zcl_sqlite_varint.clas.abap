CLASS zcl_sqlite_varint DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS lc_mask_7f TYPE x LENGTH 1 VALUE '7F'.
    CONSTANTS lc_mask_80 TYPE x LENGTH 1 VALUE '80'.
    CONSTANTS lc_zero    TYPE x LENGTH 1 VALUE '00'.

    CLASS-METHODS decode
      IMPORTING iv_buffer     TYPE xstring
                iv_offset     TYPE i DEFAULT 0
      EXPORTING ev_value      TYPE int8
                ev_bytes_read TYPE i.
ENDCLASS.


CLASS zcl_sqlite_varint IMPLEMENTATION.
  METHOD decode.
    DATA lv_len         TYPE i.
    DATA lv_max         TYPE i.
    DATA lv_val         TYPE int8.
    DATA lv_byte_raw    TYPE x LENGTH 1.
    DATA lv_payload_raw TYPE x LENGTH 1.
    DATA lv_masked      TYPE x LENGTH 1.
    DATA lv_b           TYPE i.
    DATA lv_payload     TYPE i.
    DATA lv_i           TYPE i.
    DATA lv_cur_offset  TYPE i.

    lv_cur_offset = iv_offset.
    lv_len = xstrlen( iv_buffer ) - lv_cur_offset.
    IF lv_len <= 0.
      ev_value = 0.
      ev_bytes_read = 0.
      RETURN.
    ENDIF.

    lv_max = 9.
    IF lv_len < lv_max.
      lv_max = lv_len.
    ENDIF.

    lv_val = 0.
    lv_i = 0.
    WHILE lv_i < lv_max.
      lv_byte_raw = iv_buffer+lv_cur_offset(1).
      lv_cur_offset = lv_cur_offset + 1.
      lv_b = lv_byte_raw.

      IF lv_i < 8.
        lv_payload_raw = lv_byte_raw BIT-AND lc_mask_7f.
        lv_payload = lv_payload_raw.
        lv_val = ( lv_val * 128 ) + lv_payload.
        lv_masked = lv_byte_raw BIT-AND lc_mask_80.
        IF lv_masked = lc_zero.
          ev_value = lv_val.
          ev_bytes_read = lv_i + 1.
          RETURN.
        ENDIF.
      ELSE.
        lv_val = ( lv_val * 256 ) + lv_b.
        ev_value = lv_val.
        ev_bytes_read = 9.
        RETURN.
      ENDIF.

      lv_i = lv_i + 1.
    ENDWHILE.

    ev_value = lv_val.
    ev_bytes_read = lv_max.
  ENDMETHOD.
ENDCLASS.
