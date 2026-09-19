CLASS zcl_sqlite_row DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    DATA mv_rowid   TYPE int8                           READ-ONLY.
    DATA mt_columns TYPE zcl_sqlite_types=>ty_t_columns READ-ONLY.

    METHODS constructor
      IMPORTING iv_rowid   TYPE int8
                it_columns TYPE zcl_sqlite_types=>ty_t_columns OPTIONAL.

    METHODS get_value_by_index
      IMPORTING iv_index      TYPE i
      RETURNING VALUE(rs_val) TYPE zcl_sqlite_types=>ty_s_value.

    METHODS get_value_by_name
      IMPORTING iv_name       TYPE string
      RETURNING VALUE(rs_val) TYPE zcl_sqlite_types=>ty_s_value.

    METHODS to_string
      RETURNING VALUE(rv_str) TYPE string.
ENDCLASS.


CLASS zcl_sqlite_row IMPLEMENTATION.
  METHOD constructor.
    mv_rowid   = iv_rowid.
    mt_columns = it_columns.
  ENDMETHOD.

  METHOD get_value_by_index.
    DATA ls_col TYPE zcl_sqlite_types=>ty_s_column.

    READ TABLE mt_columns INTO ls_col WITH KEY index = iv_index.
    IF sy-subrc = 0.
      rs_val = ls_col-value.
    ELSE.
      rs_val = zcl_sqlite_types=>value_null( ).
    ENDIF.
  ENDMETHOD.

  METHOD get_value_by_name.
    DATA lv_target TYPE string.
    DATA ls_col    LIKE LINE OF mt_columns.

    lv_target = to_upper( iv_name ).

    LOOP AT mt_columns INTO ls_col.
      IF to_upper( ls_col-name ) = lv_target.
        rs_val = ls_col-value.
        RETURN.
      ENDIF.
    ENDLOOP.
    rs_val = zcl_sqlite_types=>value_null( ).
  ENDMETHOD.

  METHOD to_string.
    DATA lt_parts   TYPE string_table.
    DATA ls_col     LIKE LINE OF mt_columns.
    DATA lv_val_str TYPE string.
    DATA lv_part    LIKE LINE OF lt_parts.
    DATA lv_joined  TYPE string.

    LOOP AT mt_columns INTO ls_col.

      lv_val_str = zcl_sqlite_types=>value_to_string( ls_col-value ).

      lv_part = |{ ls_col-name }: { lv_val_str }|.
      INSERT lv_part INTO TABLE lt_parts.
    ENDLOOP.

    lv_joined = concat_lines_of( table = lt_parts
                                 sep   = ' | ' ).
    rv_str = |[RowID: { mv_rowid }] { lv_joined }|.
  ENDMETHOD.
ENDCLASS.
