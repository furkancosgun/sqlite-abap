CLASS zcl_sqlite_overflow_handler DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS reassemble
      IMPORTING io_reader       TYPE REF TO zcl_sqlite_reader
                iv_cell_payload TYPE xstring
                iv_payload_size TYPE int8
                iv_local_size   TYPE i
                iv_overflow_ptr TYPE i
                iv_cell_buffer  TYPE xstring
      RETURNING VALUE(rv_payload) TYPE xstring
      RAISING   zcx_sqlite_error.

    CLASS-METHODS calc_local_size
      IMPORTING iv_payload_size TYPE int8
                iv_usable_size  TYPE i
      RETURNING VALUE(rv_local) TYPE i.

  PRIVATE SECTION.
    CLASS-METHODS read_overflow_chain
      IMPORTING io_reader      TYPE REF TO zcl_sqlite_reader
                iv_start_page  TYPE i
                iv_total_size  TYPE int8
                iv_offset      TYPE i
                iv_usable_size TYPE i
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   zcx_sqlite_error.
ENDCLASS.


CLASS zcl_sqlite_overflow_handler IMPLEMENTATION.
  METHOD calc_local_size.
    DATA lv_max TYPE i.
    DATA lv_min TYPE i.
    DATA lv_rem TYPE i.

    lv_max = iv_usable_size - 35.
    lv_min = ( ( ( iv_usable_size - 12 ) * 32 ) / 255 ) - 23.

    IF iv_payload_size <= lv_max.
      rv_local = iv_payload_size.
    ELSE.
      lv_rem = ( iv_payload_size - lv_min ) MOD ( iv_usable_size - 4 ).
      IF lv_min + lv_rem <= lv_max.
        rv_local = lv_min + lv_rem.
      ELSE.
        rv_local = lv_min.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD reassemble.
    DATA lv_page TYPE i.
    DATA lv_chain TYPE xstring.

    IF iv_payload_size = iv_local_size.
      rv_payload = iv_cell_payload.
      RETURN.
    ENDIF.

    rv_payload = iv_cell_payload.
    lv_page = zcl_sqlite_codec=>read_int32( iv_buf = iv_cell_buffer
                                            iv_off = iv_overflow_ptr ).

    lv_chain = read_overflow_chain( io_reader      = io_reader
                                    iv_start_page  = lv_page
                                    iv_total_size  = iv_payload_size
                                    iv_offset      = iv_local_size
                                    iv_usable_size = io_reader->get_usable_page_size( ) ).

    CONCATENATE rv_payload lv_chain INTO rv_payload IN BYTE MODE.
  ENDMETHOD.

  METHOD read_overflow_chain.
    DATA lv_page TYPE i.
    DATA lv_off  TYPE i.
    DATA lv_max  TYPE i.
    DATA lv_mem  TYPE xstring.
    DATA lv_next TYPE i.
    DATA lv_len  TYPE i.
    DATA lv_chunk TYPE xstring.

    lv_page = iv_start_page.
    lv_off = iv_offset.
    lv_max = iv_usable_size - 4.

    WHILE lv_off < iv_total_size AND lv_page > 0.
      lv_mem = io_reader->read_page( lv_page ).
      lv_next = zcl_sqlite_codec=>read_int32( iv_buf = lv_mem
                                              iv_off = 0 ).
      lv_len = iv_total_size - lv_off.
      IF lv_len > lv_max.
        lv_len = lv_max.
      ENDIF.
      lv_chunk = lv_mem+4(lv_len).
      CONCATENATE rv_data lv_chunk INTO rv_data IN BYTE MODE.
      lv_off = lv_off + lv_len.
      lv_page = lv_next.
    ENDWHILE.
  ENDMETHOD.
ENDCLASS.
