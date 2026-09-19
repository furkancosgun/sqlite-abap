CLASS zcx_sqlite_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_message TYPE string.

    CLASS-METHODS raise
      IMPORTING iv_message TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS raise_syst
      RAISING zcx_sqlite_error.

    METHODS get_text REDEFINITION.

  PRIVATE SECTION.
    DATA mv_message TYPE string.
ENDCLASS.


CLASS zcx_sqlite_error IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( ).
    mv_message = iv_message.
  ENDMETHOD.

  METHOD get_text.
    result = mv_message.
  ENDMETHOD.

  METHOD raise.
    DATA lo_excep TYPE REF TO zcx_sqlite_error.

    CREATE OBJECT lo_excep TYPE zcx_sqlite_error EXPORTING iv_message = iv_message.
    RAISE EXCEPTION lo_excep.
  ENDMETHOD.

  METHOD raise_syst.
    DATA lv_message TYPE string.
    DATA lo_excep   TYPE REF TO zcx_sqlite_error.

    MESSAGE ID sy-msgid
            TYPE sy-msgty
            NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
            INTO lv_message.

    CREATE OBJECT lo_excep TYPE zcx_sqlite_error EXPORTING iv_message = lv_message.
    RAISE EXCEPTION lo_excep.
  ENDMETHOD.
ENDCLASS.
