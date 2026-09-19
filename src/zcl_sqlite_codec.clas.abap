CLASS zcl_sqlite_codec DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS read_uint8
      IMPORTING iv_buf        TYPE xstring
                iv_off        TYPE i DEFAULT 0
      RETURNING VALUE(rv_val) TYPE i.

    CLASS-METHODS read_int8_val
      IMPORTING iv_buf        TYPE xstring
                iv_off        TYPE i DEFAULT 0
      RETURNING VALUE(rv_val) TYPE i.

    CLASS-METHODS read_uint16
      IMPORTING iv_buf        TYPE xstring
                iv_off        TYPE i DEFAULT 0
      RETURNING VALUE(rv_val) TYPE i.

    CLASS-METHODS read_int16
      IMPORTING iv_buf        TYPE xstring
                iv_off        TYPE i DEFAULT 0
      RETURNING VALUE(rv_val) TYPE i.

    CLASS-METHODS read_int24
      IMPORTING iv_buf        TYPE xstring
                iv_off        TYPE i DEFAULT 0
      RETURNING VALUE(rv_val) TYPE i.

    CLASS-METHODS read_int32
      IMPORTING iv_buf        TYPE xstring
                iv_off        TYPE i DEFAULT 0
      RETURNING VALUE(rv_val) TYPE i.

    CLASS-METHODS read_int48
      IMPORTING iv_buf        TYPE xstring
                iv_off        TYPE i DEFAULT 0
      RETURNING VALUE(rv_val) TYPE int8.

    CLASS-METHODS read_int64
      IMPORTING iv_buf        TYPE xstring
                iv_off        TYPE i DEFAULT 0
      RETURNING VALUE(rv_val) TYPE int8.

    CLASS-METHODS read_double
      IMPORTING iv_buf        TYPE xstring
                iv_off        TYPE i DEFAULT 0
      RETURNING VALUE(rv_val) TYPE f.

    CLASS-METHODS read_text
      IMPORTING iv_buf        TYPE xstring
                iv_off        TYPE i DEFAULT 0
                iv_len        TYPE i
      RETURNING VALUE(rv_val) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS read_bytes
      IMPORTING iv_buf        TYPE xstring
                iv_off        TYPE i DEFAULT 0
                iv_len        TYPE i
      RETURNING VALUE(rv_val) TYPE xstring.

    CLASS-METHODS read
      IMPORTING iv_buf TYPE xstring
                iv_len TYPE i OPTIONAL
                iv_off TYPE i OPTIONAL
      EXPORTING ev_val TYPE simple
      RAISING   zcx_sqlite_error.

  PRIVATE SECTION.
    CLASS-METHODS read_be_unsigned
      IMPORTING iv_buf        TYPE xstring
                iv_off        TYPE i
                iv_len        TYPE i
      RETURNING VALUE(rv_val) TYPE int8.

    CLASS-METHODS apply_sign_i
      IMPORTING iv_unsigned   TYPE int8
                iv_bits       TYPE i
      RETURNING VALUE(rv_val) TYPE i.

    CLASS-METHODS apply_sign_int8
      IMPORTING iv_unsigned   TYPE int8
                iv_bits       TYPE i
      RETURNING VALUE(rv_val) TYPE int8.
ENDCLASS.


CLASS zcl_sqlite_codec IMPLEMENTATION.
  METHOD read_uint8.
    DATA lv_raw TYPE x LENGTH 1.

    lv_raw = iv_buf+iv_off(1).
    rv_val = lv_raw.
  ENDMETHOD.

  METHOD read_be_unsigned.
    DATA lv_raw TYPE x LENGTH 1.
    DATA lv_num TYPE i.
    DATA lv_off TYPE i.
    DATA lv_i   TYPE i.

    rv_val = 0.
    lv_off = iv_off.
    lv_i = 0.
    WHILE lv_i < iv_len.
      lv_raw = iv_buf+lv_off(1).
      lv_num = lv_raw.
      rv_val = ( rv_val * 256 ) + lv_num.
      lv_off = lv_off + 1.
      lv_i = lv_i + 1.
    ENDWHILE.
  ENDMETHOD.

  METHOD apply_sign_i.
    DATA lv_threshold TYPE int8.
    DATA lv_range     TYPE int8.

    lv_threshold = 2 ** ( iv_bits - 1 ).
    IF iv_unsigned >= lv_threshold.
      lv_range = 2 ** iv_bits.
      rv_val = iv_unsigned - lv_range.
    ELSE.
      rv_val = iv_unsigned.
    ENDIF.
  ENDMETHOD.

  METHOD apply_sign_int8.
    DATA lv_threshold TYPE int8.
    DATA lv_range     TYPE int8.

    lv_threshold = 2 ** ( iv_bits - 1 ).
    IF iv_unsigned >= lv_threshold.
      lv_range = 2 ** iv_bits.
      rv_val = iv_unsigned - lv_range.
    ELSE.
      rv_val = iv_unsigned.
    ENDIF.
  ENDMETHOD.

  METHOD read_int8_val.
    DATA lv_u TYPE int8.

    lv_u = read_uint8( iv_buf = iv_buf
                       iv_off = iv_off ).
    rv_val = apply_sign_i( iv_unsigned = lv_u
                           iv_bits     = 8 ).
  ENDMETHOD.

  METHOD read_uint16.
    rv_val = read_be_unsigned( iv_buf = iv_buf
                               iv_off = iv_off
                               iv_len = 2 ).
  ENDMETHOD.

  METHOD read_int16.
    DATA lv_u TYPE int8.

    lv_u = read_be_unsigned( iv_buf = iv_buf
                             iv_off = iv_off
                             iv_len = 2 ).
    rv_val = apply_sign_i( iv_unsigned = lv_u
                           iv_bits     = 16 ).
  ENDMETHOD.

  METHOD read_int24.
    DATA lv_u TYPE int8.

    lv_u = read_be_unsigned( iv_buf = iv_buf
                             iv_off = iv_off
                             iv_len = 3 ).
    rv_val = apply_sign_i( iv_unsigned = lv_u
                           iv_bits     = 24 ).
  ENDMETHOD.

  METHOD read_int32.
    DATA lv_u TYPE int8.

    lv_u = read_be_unsigned( iv_buf = iv_buf
                             iv_off = iv_off
                             iv_len = 4 ).
    rv_val = apply_sign_int8( iv_unsigned = lv_u
                              iv_bits     = 32 ).
  ENDMETHOD.

  METHOD read_int48.
    DATA lv_u TYPE int8.

    lv_u = read_be_unsigned( iv_buf = iv_buf
                             iv_off = iv_off
                             iv_len = 6 ).
    rv_val = apply_sign_int8( iv_unsigned = lv_u
                              iv_bits     = 48 ).
  ENDMETHOD.

  METHOD read_int64.
    DATA lv_b0      TYPE x LENGTH 1.
    DATA lv_raw     TYPE x LENGTH 1.
    DATA lv_i0      TYPE i.
    DATA lv_num     TYPE i.
    DATA lv_off     TYPE i.
    DATA lv_val     TYPE int8.
    DATA lv_max_pos TYPE int8.
    DATA lv_i       TYPE i.

    lv_b0 = iv_buf+iv_off(1).
    lv_i0 = lv_b0.

    IF lv_i0 >= 128.
      lv_val = lv_i0 - 128.
      lv_off = iv_off + 1.
      lv_i = 0.
      WHILE lv_i < 7.
        lv_raw = iv_buf+lv_off(1).
        lv_num = lv_raw.
        lv_val = ( lv_val * 256 ) + lv_num.
        lv_off = lv_off + 1.
        lv_i = lv_i + 1.
      ENDWHILE.
      lv_max_pos = 9223372036854775807.
      rv_val = ( lv_val - lv_max_pos ) - 1.
    ELSE.
      lv_val = read_be_unsigned( iv_buf = iv_buf
                                 iv_off = iv_off
                                 iv_len = 8 ).
      rv_val = lv_val.
    ENDIF.
  ENDMETHOD.

  METHOD read_double.
    DATA lv_b0       TYPE x LENGTH 1.
    DATA lv_b1       TYPE x LENGTH 1.
    DATA lv_raw      TYPE x LENGTH 1.
    DATA lv_i0       TYPE i.
    DATA lv_i1       TYPE i.
    DATA lv_sign     TYPE i.
    DATA lv_exp      TYPE i.
    DATA lv_num      TYPE i.
    DATA lv_off      TYPE i.
    DATA lv_mantissa TYPE f.
    DATA lv_frac     TYPE f.
    DATA lv_pow      TYPE f.
    DATA lv_exp_diff TYPE i.
    DATA lv_i        TYPE i.

    lv_b0 = iv_buf+iv_off(1).
    lv_off = iv_off + 1.
    lv_b1 = iv_buf+lv_off(1).
    lv_i0 = lv_b0.
    lv_i1 = lv_b1.

    IF lv_i0 >= 128.
      lv_sign = 1.
      lv_i0 = lv_i0 - 128.
    ELSE.
      lv_sign = 0.
    ENDIF.

    lv_exp = ( lv_i0 * 16 ) + ( lv_i1 / 16 ).
    lv_mantissa = lv_i1 MOD 16.

    lv_off = iv_off + 2.
    lv_i = 0.
    WHILE lv_i < 6.
      lv_raw = iv_buf+lv_off(1).
      lv_num = lv_raw.
      lv_mantissa = ( lv_mantissa * 256 ) + lv_num.
      lv_off = lv_off + 1.
      lv_i = lv_i + 1.
    ENDWHILE.

    CASE lv_exp.
      WHEN 0.
        IF lv_mantissa = 0.
          rv_val = 0.
          RETURN.
        ENDIF.
        lv_frac = lv_mantissa / '4503599627370496.0'.
        lv_exp_diff = -1022.
      WHEN 2047.
        rv_val = 0.
        RETURN.
      WHEN OTHERS.
        lv_frac = 1 + ( lv_mantissa / '4503599627370496.0' ).
        lv_exp_diff = lv_exp - 1023.
    ENDCASE.

    lv_pow = 2 ** lv_exp_diff.
    rv_val = lv_frac * lv_pow.

    IF lv_sign = 1.
      rv_val = - rv_val.
    ENDIF.
  ENDMETHOD.

  METHOD read_text.
    DATA lv_slice   TYPE xstring.
    DATA lo_conv    TYPE REF TO cl_abap_conv_in_ce.
    DATA lx_err     TYPE REF TO cx_root.
    DATA lv_err_msg TYPE string.

    IF iv_len <= 0.
      rv_val = ''.
      RETURN.
    ENDIF.
    lv_slice = iv_buf+iv_off(iv_len).
    TRY.
        lo_conv = cl_abap_conv_in_ce=>create( encoding = 'UTF-8' ).
        lo_conv->convert( EXPORTING input = lv_slice
                          IMPORTING data  = rv_val ).
      CATCH cx_root INTO lx_err.
        lv_err_msg = lx_err->get_text( ).
        zcx_sqlite_error=>raise( lv_err_msg ).
    ENDTRY.
  ENDMETHOD.

  METHOD read_bytes.
    IF iv_len <= 0.
      CLEAR rv_val.
      RETURN.
    ENDIF.
    rv_val = iv_buf+iv_off(iv_len).
  ENDMETHOD.

  METHOD read.
    DATA lv_buffer TYPE xstring.
    DATA lv_len    TYPE i.

    lv_buffer = iv_buf.
    IF iv_off IS SUPPLIED.
      lv_buffer = lv_buffer+iv_off.
    ENDIF.
    IF iv_len IS SUPPLIED.
      lv_buffer = lv_buffer(iv_len).
    ENDIF.
    lv_len = xstrlen( lv_buffer ).
    CASE lv_len.
      WHEN 1.
        ev_val = read_uint8( lv_buffer ).
      WHEN 2.
        ev_val = read_uint16( lv_buffer ).
      WHEN 4.
        ev_val = read_int32( lv_buffer ).
      WHEN OTHERS.
        zcx_sqlite_error=>raise( 'Unsupported byte length for conversion' ).
    ENDCASE.
  ENDMETHOD.
ENDCLASS.
