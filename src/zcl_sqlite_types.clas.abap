CLASS zcl_sqlite_types DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF c_type,
        null    TYPE string VALUE 'NULL',
        integer TYPE string VALUE 'INTEGER',
        real    TYPE string VALUE 'REAL',
        text    TYPE string VALUE 'TEXT',
        blob    TYPE string VALUE 'BLOB',
      END OF c_type.

    TYPES:
      BEGIN OF ty_s_value,
        data_type     TYPE string,
        integer_value TYPE int8,
        real_value    TYPE f,
        text_value    TYPE string,
        blob_value    TYPE xstring,
      END OF ty_s_value.

    TYPES:
      BEGIN OF ty_s_column,
        index TYPE i,
        name  TYPE string,
        value TYPE ty_s_value,
      END OF ty_s_column,
      ty_t_columns TYPE STANDARD TABLE OF ty_s_column WITH KEY index.

    TYPES:
      BEGIN OF ty_s_schema,
        type              TYPE string,
        name              TYPE string,
        tbl_name          TYPE string,
        rootpage          TYPE i,
        sql               TYPE string,
        column_names      TYPE string_table,
        rowid_alias_index TYPE i,
        has_rowid_alias   TYPE abap_bool,
        is_without_rowid  TYPE abap_bool,
      END OF ty_s_schema,
      ty_t_schemas TYPE STANDARD TABLE OF ty_s_schema WITH KEY name.

    CLASS-METHODS value_null
      RETURNING VALUE(rs_val) TYPE ty_s_value.

    CLASS-METHODS value_from_integer
      IMPORTING iv_val        TYPE int8
      RETURNING VALUE(rs_val) TYPE ty_s_value.

    CLASS-METHODS value_from_real
      IMPORTING iv_val        TYPE f
      RETURNING VALUE(rs_val) TYPE ty_s_value.

    CLASS-METHODS value_from_text
      IMPORTING iv_val        TYPE string
      RETURNING VALUE(rs_val) TYPE ty_s_value.

    CLASS-METHODS value_from_blob
      IMPORTING iv_val        TYPE xstring
      RETURNING VALUE(rs_val) TYPE ty_s_value.

    CLASS-METHODS value_to_string
      IMPORTING is_val        TYPE ty_s_value
      RETURNING VALUE(rv_str) TYPE string.
ENDCLASS.


CLASS zcl_sqlite_types IMPLEMENTATION.
  METHOD value_null.
    rs_val-data_type = c_type-null.
  ENDMETHOD.

  METHOD value_from_integer.
    rs_val-data_type     = c_type-integer.
    rs_val-integer_value = iv_val.
  ENDMETHOD.

  METHOD value_from_real.
    rs_val-data_type  = c_type-real.
    rs_val-real_value = iv_val.
  ENDMETHOD.

  METHOD value_from_text.
    rs_val-data_type  = c_type-text.
    rs_val-text_value = iv_val.
  ENDMETHOD.

  METHOD value_from_blob.
    rs_val-data_type  = c_type-blob.
    rs_val-blob_value = iv_val.
  ENDMETHOD.

  METHOD value_to_string.
    DATA lv_len TYPE i.

    CASE is_val-data_type.
      WHEN c_type-null.
        rv_str = 'NULL'.
      WHEN c_type-integer.
        rv_str = |{ is_val-integer_value }|.
      WHEN c_type-real.
        rv_str = |{ is_val-real_value }|.
      WHEN c_type-text.
        rv_str = is_val-text_value.
      WHEN c_type-blob.
        lv_len = xstrlen( is_val-blob_value ).
        rv_str = |BLOB[{ lv_len } bytes]|.
      WHEN OTHERS.
        rv_str = 'UNKNOWN'.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.
