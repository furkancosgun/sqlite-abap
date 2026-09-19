CLASS zcl_sqlite_schema_parser DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS extract_column_names
      IMPORTING iv_sql          TYPE string
      RETURNING VALUE(rt_names) TYPE string_table.

    CLASS-METHODS get_rowid_alias_index
      IMPORTING iv_sql          TYPE string
      RETURNING VALUE(rv_index) TYPE i.

    CLASS-METHODS is_without_rowid
      IMPORTING iv_sql        TYPE string
      RETURNING VALUE(rv_res) TYPE abap_bool.

    CLASS-METHODS split_columns
      IMPORTING iv_body        TYPE string
      RETURNING VALUE(rt_cols) TYPE string_table.

    CLASS-METHODS clean_string
      IMPORTING iv_str            TYPE string
      RETURNING VALUE(rv_cleaned) TYPE string.

  PRIVATE SECTION.
    CLASS-METHODS extract_name_from_coldef
      IMPORTING iv_coldef      TYPE string
      RETURNING VALUE(rv_name) TYPE string.

    CLASS-METHODS get_table_body
      IMPORTING iv_sql         TYPE string
      RETURNING VALUE(rv_body) TYPE string.

    CLASS-METHODS is_constraint_def
      IMPORTING iv_upper      TYPE string
      RETURNING VALUE(rv_yes) TYPE abap_bool.

    CLASS-METHODS is_rowid_alias_def
      IMPORTING iv_upper      TYPE string
      RETURNING VALUE(rv_yes) TYPE abap_bool.

    CLASS-METHODS is_whitespace
      IMPORTING iv_char       TYPE string
      RETURNING VALUE(rv_yes) TYPE abap_bool.

    CLASS-METHODS extract_quoted_name
      IMPORTING iv_coldef      TYPE string
                iv_quote       TYPE string
      RETURNING VALUE(rv_name) TYPE string.
ENDCLASS.


CLASS zcl_sqlite_schema_parser IMPLEMENTATION.
  METHOD is_whitespace.
    rv_yes = boolc( iv_char = ` ` OR iv_char = cl_abap_char_utilities=>horizontal_tab
                    OR iv_char = cl_abap_char_utilities=>cr_lf(1)
                    OR iv_char = cl_abap_char_utilities=>cr_lf+1(1)
                    OR iv_char = cl_abap_char_utilities=>newline ).
  ENDMETHOD.

  METHOD clean_string.
    DATA lv_len     TYPE i.
    DATA lv_start   TYPE i VALUE 0.
    DATA lv_end     TYPE i.
    DATA lv_c       TYPE string.
    DATA lv_sub_len TYPE i.

    lv_len = strlen( iv_str ).

    WHILE lv_start < lv_len.
      lv_c = substring( val = iv_str
                        off = lv_start
                        len = 1 ).
      IF is_whitespace( lv_c ) = abap_true.
        lv_start = lv_start + 1.
      ELSE.
        EXIT.
      ENDIF.
    ENDWHILE.

    lv_end = lv_len - 1.
    WHILE lv_end >= lv_start.
      lv_c = substring( val = iv_str
                        off = lv_end
                        len = 1 ).
      IF is_whitespace( lv_c ) = abap_true.
        lv_end = lv_end - 1.
      ELSE.
        EXIT.
      ENDIF.
    ENDWHILE.

    IF lv_start <= lv_end.
      lv_sub_len = lv_end - lv_start + 1.
      rv_cleaned = substring( val = iv_str
                              off = lv_start
                              len = lv_sub_len ).
    ELSE.
      rv_cleaned = ''.
    ENDIF.
  ENDMETHOD.

  METHOD is_without_rowid.
    rv_res = boolc( to_upper( iv_sql ) CS 'WITHOUT ROWID' ).
  ENDMETHOD.

  METHOD get_table_body.
    DATA lv_open     TYPE i.
    DATA lv_close    TYPE i.
    DATA lv_len      TYPE i.
    DATA lv_body_off TYPE i.

    lv_open = find( val = iv_sql
                    sub = '(' ).
    lv_close = find( val = iv_sql
                     sub = ')'
                     occ = -1 ).

    IF lv_open < 0 OR lv_close <= lv_open.
      RETURN.
    ENDIF.

    lv_len = lv_close - lv_open - 1.
    lv_body_off = lv_open + 1.
    rv_body = substring( val = iv_sql
                         off = lv_body_off
                         len = lv_len ).
  ENDMETHOD.

  METHOD is_constraint_def.
    rv_yes = boolc( iv_upper CP 'PRIMARY *' OR iv_upper CP 'PRIMARY(*'
                    OR iv_upper CP 'FOREIGN *' OR iv_upper CP 'CONSTRAINT *'
                    OR iv_upper CP 'UNIQUE *' OR iv_upper CP 'UNIQUE(*'
                    OR iv_upper CP 'CHECK *' OR iv_upper CP 'CHECK(*' ).
  ENDMETHOD.

  METHOD is_rowid_alias_def.
    rv_yes = boolc( ( iv_upper CP '* INTEGER *' OR iv_upper CP 'INTEGER *' )
                    AND iv_upper CS 'PRIMARY KEY' ).
  ENDMETHOD.

  METHOD extract_column_names.
    DATA lv_body    TYPE string.
    DATA lt_defs    TYPE string_table.
    DATA lv_def     LIKE LINE OF lt_defs.
    DATA lv_trimmed TYPE string.
    DATA lv_upper   TYPE string.
    DATA lv_name    TYPE string.

    lv_body = get_table_body( iv_sql ).
    IF lv_body IS INITIAL.
      RETURN.
    ENDIF.

    lt_defs = split_columns( lv_body ).

    LOOP AT lt_defs INTO lv_def.
      lv_trimmed = clean_string( lv_def ).
      IF lv_trimmed IS INITIAL.
        CONTINUE.
      ENDIF.

      lv_upper = to_upper( lv_trimmed ).
      IF is_constraint_def( lv_upper ) = abap_true.
        CONTINUE.
      ENDIF.

      lv_name = extract_name_from_coldef( lv_trimmed ).
      IF lv_name IS NOT INITIAL.
        INSERT lv_name INTO TABLE rt_names.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_rowid_alias_index.
    DATA lv_body    TYPE string.
    DATA lt_defs    TYPE string_table.
    DATA lv_col_idx TYPE i.
    DATA lv_def     LIKE LINE OF lt_defs.
    DATA lv_trimmed TYPE string.
    DATA lv_upper   TYPE string.

    rv_index = -1.

    IF iv_sql IS INITIAL OR is_without_rowid( iv_sql ) = abap_true.
      RETURN.
    ENDIF.

    lv_body = get_table_body( iv_sql ).
    IF lv_body IS INITIAL.
      RETURN.
    ENDIF.

    lt_defs = split_columns( lv_body ).
    lv_col_idx = 0.

    LOOP AT lt_defs INTO lv_def.
      lv_trimmed = clean_string( lv_def ).
      IF lv_trimmed IS INITIAL.
        CONTINUE.
      ENDIF.

      lv_upper = to_upper( lv_trimmed ).
      IF is_constraint_def( lv_upper ) = abap_true.
        CONTINUE.
      ENDIF.

      IF is_rowid_alias_def( lv_upper ) = abap_true.
        rv_index = lv_col_idx.
        RETURN.
      ENDIF.

      lv_col_idx = lv_col_idx + 1.
    ENDLOOP.
  ENDMETHOD.

  METHOD split_columns.
    DATA lv_depth     TYPE i          VALUE 0.
    DATA lv_start     TYPE i          VALUE 0.
    DATA lv_len       TYPE i.
    DATA lv_i         TYPE i.
    DATA lv_char      TYPE c LENGTH 1.
    DATA lv_chunk_len TYPE i.
    DATA lv_part      TYPE string.
    DATA lv_rem_len   TYPE i.
    DATA lv_rem       TYPE string.

    lv_len = strlen( iv_body ).
    lv_i = 0.
    WHILE lv_i < lv_len.
      lv_char = substring( val = iv_body
                           off = lv_i
                           len = 1 ).
      IF lv_char = '('.
        lv_depth = lv_depth + 1.
      ELSEIF lv_char = ')'.
        lv_depth = lv_depth - 1.
      ELSEIF lv_char = ',' AND lv_depth = 0.
        lv_chunk_len = lv_i - lv_start.
        IF lv_chunk_len > 0.
          lv_part = substring( val = iv_body
                               off = lv_start
                               len = lv_chunk_len ).
          INSERT lv_part INTO TABLE rt_cols.
        ENDIF.
        lv_start = lv_i + 1.
      ENDIF.
      lv_i = lv_i + 1.
    ENDWHILE.

    IF lv_start < lv_len.
      lv_rem_len = lv_len - lv_start.
      lv_rem = substring( val = iv_body
                          off = lv_start
                          len = lv_rem_len ).
      INSERT lv_rem INTO TABLE rt_cols.
    ENDIF.
  ENDMETHOD.

  METHOD extract_quoted_name.
    DATA lv_end TYPE i.

    lv_end = find( val = iv_coldef
                   sub = iv_quote
                   off = 1 ).
    IF lv_end > 1.
      rv_name = substring( val = iv_coldef
                           off = 1
                           len = lv_end - 1 ).
    ENDIF.
  ENDMETHOD.

  METHOD extract_name_from_coldef.
    DATA lv_first TYPE string.
    DATA lv_len   TYPE i.
    DATA lv_i     TYPE i VALUE 0.
    DATA lv_c     TYPE string.

    lv_first = substring( val = iv_coldef
                          off = 0
                          len = 1 ).
    lv_len = strlen( iv_coldef ).

    CASE lv_first.
      WHEN '['.
        rv_name = extract_quoted_name( iv_coldef = iv_coldef
                                       iv_quote  = ']' ).
        IF rv_name IS NOT INITIAL.
          RETURN.
        ENDIF.
      WHEN '"'.
        rv_name = extract_quoted_name( iv_coldef = iv_coldef
                                       iv_quote  = '"' ).
        IF rv_name IS NOT INITIAL.
          RETURN.
        ENDIF.
      WHEN '`'.
        rv_name = extract_quoted_name( iv_coldef = iv_coldef
                                       iv_quote  = '`' ).
        IF rv_name IS NOT INITIAL.
          RETURN.
        ENDIF.
    ENDCASE.

    WHILE lv_i < lv_len.
      lv_c = substring( val = iv_coldef
                        off = lv_i
                        len = 1 ).
      IF is_whitespace( lv_c ) = abap_true OR lv_c = '('.
        EXIT.
      ENDIF.
      lv_i = lv_i + 1.
    ENDWHILE.

    IF lv_i > 0.
      rv_name = substring( val = iv_coldef
                           off = 0
                           len = lv_i ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
