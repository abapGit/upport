CLASS zcl_abapgit_gui_event DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES zif_abapgit_gui_event .

    METHODS constructor
      IMPORTING
        !ii_gui_services TYPE REF TO zif_abapgit_gui_services OPTIONAL
        !iv_action       TYPE clike
        !iv_getdata      TYPE clike OPTIONAL
        !it_postdata     TYPE cnht_post_data_tab OPTIONAL .
  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mo_query TYPE REF TO zcl_abapgit_string_map.
    DATA mo_query_upper_cased TYPE REF TO zcl_abapgit_string_map.

    METHODS fields_to_map
      IMPORTING
        it_fields            TYPE tihttpnvp
      RETURNING
        VALUE(ro_string_map) TYPE REF TO zcl_abapgit_string_map
      RAISING
        zcx_abapgit_exception.

ENDCLASS.



CLASS ZCL_ABAPGIT_GUI_EVENT IMPLEMENTATION.


  METHOD constructor.

    zif_abapgit_gui_event~mi_gui_services = ii_gui_services.
    zif_abapgit_gui_event~mv_action       = iv_action.
    zif_abapgit_gui_event~mv_getdata      = iv_getdata.
    zif_abapgit_gui_event~mt_postdata     = it_postdata.

  ENDMETHOD.


  METHOD fields_to_map.
    FIELD-SYMBOLS <ls_field> LIKE LINE OF it_fields.

    ro_string_map = NEW #( ).
    LOOP AT it_fields ASSIGNING <ls_field>.
      ro_string_map->set(
        iv_key = <ls_field>-name
        iv_val = <ls_field>-value ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_abapgit_gui_event~query.

    DATA lt_fields TYPE tihttpnvp.

    IF iv_upper_cased = abap_true.
      IF mo_query_upper_cased IS NOT BOUND.
        mo_query_upper_cased = fields_to_map(
          zcl_abapgit_html_action_utils=>parse_fields_upper_case_name( zif_abapgit_gui_event~mv_getdata ) ).
        mo_query_upper_cased->freeze( ).
      ENDIF.
      ro_string_map = mo_query_upper_cased.
    ELSE.
      IF mo_query IS NOT BOUND.
        mo_query = fields_to_map(
          zcl_abapgit_html_action_utils=>parse_fields( zif_abapgit_gui_event~mv_getdata ) ).
        mo_query->freeze( ).
      ENDIF.
      ro_string_map = mo_query.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
