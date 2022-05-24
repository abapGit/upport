CLASS zcl_abapgit_data_serializer DEFINITION
  PUBLIC
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_abapgit_data_factory .

  PUBLIC SECTION.

    INTERFACES zif_abapgit_data_serializer .

  PROTECTED SECTION.

  PRIVATE SECTION.

    CONSTANTS c_max_records TYPE i VALUE 10000 ##NO_TEXT.

    METHODS convert_itab_to_json
      IMPORTING
        !ir_data       TYPE REF TO data
      RETURNING
        VALUE(rv_data) TYPE xstring
      RAISING
        zcx_abapgit_exception .
    METHODS read_database_table
      IMPORTING
        !iv_name       TYPE tadir-obj_name
        !it_where      TYPE string_table
      RETURNING
        VALUE(rr_data) TYPE REF TO data
      RAISING
        zcx_abapgit_exception .
    METHODS exists_database_table
      IMPORTING
        !iv_name         TYPE tadir-obj_name
      RETURNING
        VALUE(rv_exists) TYPE abap_bool.
ENDCLASS.



CLASS zcl_abapgit_data_serializer IMPLEMENTATION.


  METHOD convert_itab_to_json.

    DATA lo_ajson TYPE REF TO zcl_abapgit_ajson.
    DATA lv_string TYPE string.
    DATA lx_ajson TYPE REF TO zcx_abapgit_ajson_error.

    FIELD-SYMBOLS <lg_tab> TYPE ANY TABLE.

    ASSIGN ir_data->* TO <lg_tab>.

    TRY.
        lo_ajson = zcl_abapgit_ajson=>create_empty( ).
        lo_ajson->keep_item_order( ).
        lo_ajson->set(
          iv_path = '/'
          iv_val = <lg_tab> ).
        lv_string = lo_ajson->stringify( 2 ).
      CATCH zcx_abapgit_ajson_error INTO lx_ajson.
        zcx_abapgit_exception=>raise( lx_ajson->get_text( ) ).
    ENDTRY.

    rv_data = zcl_abapgit_convert=>string_to_xstring_utf8( lv_string ).

  ENDMETHOD.


  METHOD exists_database_table.

    DATA lv_table TYPE tabname.
    DATA lv_subrc TYPE sy-subrc.

    lv_table = iv_name.

    CALL FUNCTION 'DD_EXIST_TABLE'
      EXPORTING
        tabname      = lv_table
        status       = 'A'
      IMPORTING
        subrc        = lv_subrc
      EXCEPTIONS
        wrong_status = 1
        OTHERS       = 2.

    rv_exists = boolc( sy-subrc = 0 AND lv_subrc = 0 ).

  ENDMETHOD.


  METHOD read_database_table.

    DATA lv_records TYPE i.
    DATA lv_where LIKE LINE OF it_where.

    FIELD-SYMBOLS <lg_tab> TYPE ANY TABLE.

    rr_data = zcl_abapgit_data_utils=>build_table_itab( iv_name ).
    ASSIGN rr_data->* TO <lg_tab>.

    LOOP AT it_where INTO lv_where.
      SELECT * FROM (iv_name) APPENDING TABLE <lg_tab> WHERE (lv_where).
    ENDLOOP.
    IF lines( it_where ) = 0.
      SELECT * FROM (iv_name) INTO TABLE <lg_tab>.
    ENDIF.

    lv_records = lines( <lg_tab> ).
    IF lv_records > c_max_records.
      zcx_abapgit_exception=>raise( |Too many records selected from table { iv_name
        } (selected { lv_records }, max { c_max_records })| ).
    ENDIF.

  ENDMETHOD.


  METHOD zif_abapgit_data_serializer~serialize.

    DATA lt_configs TYPE zif_abapgit_data_config=>ty_config_tt.
    DATA ls_config LIKE LINE OF lt_configs.
    DATA ls_file LIKE LINE OF rt_files.
    DATA lr_data TYPE REF TO data.

    ls_file-path = zif_abapgit_data_config=>c_default_path.
    lt_configs = ii_config->get_configs( ).

    LOOP AT lt_configs INTO ls_config.
      ASSERT ls_config-type = zif_abapgit_data_config=>c_data_type-tabu. " todo
      ASSERT ls_config-name IS NOT INITIAL.

      IF exists_database_table( ls_config-name ) = abap_true.
        lr_data = read_database_table(
          iv_name  = ls_config-name
          it_where = ls_config-where ).

        ls_file-filename = zcl_abapgit_data_utils=>build_filename( ls_config ).
        ls_file-data = convert_itab_to_json( lr_data ).
        ls_file-sha1 = zcl_abapgit_hash=>sha1_blob( ls_file-data ).
        APPEND ls_file TO rt_files.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
