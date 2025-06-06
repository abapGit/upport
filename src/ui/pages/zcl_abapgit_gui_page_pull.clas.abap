CLASS zcl_abapgit_gui_page_pull DEFINITION
  PUBLIC
  INHERITING FROM zcl_abapgit_gui_component
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    INTERFACES zif_abapgit_gui_event_handler.
    INTERFACES zif_abapgit_gui_menu_provider.
    INTERFACES zif_abapgit_gui_renderable.

    CONSTANTS:
      BEGIN OF c_id,
        transport_request TYPE string VALUE 'transport_request',
      END OF c_id .

    CONSTANTS: BEGIN OF c_action,
                 pull      TYPE string VALUE 'pull',
                 refresh   TYPE string VALUE 'refresh',
                 choose_tr TYPE string VALUE 'choose_tr',
               END OF c_action.

    CLASS-METHODS create
      IMPORTING
        ii_repo        TYPE REF TO zif_abapgit_repo
        iv_trkorr      TYPE trkorr OPTIONAL
        ii_obj_filter  TYPE REF TO zif_abapgit_object_filter OPTIONAL
      RETURNING
        VALUE(ri_page) TYPE REF TO zif_abapgit_gui_renderable
      RAISING
        zcx_abapgit_exception.

    METHODS constructor
      IMPORTING
        ii_repo       TYPE REF TO zif_abapgit_repo
        iv_trkorr     TYPE trkorr
        ii_obj_filter TYPE REF TO zif_abapgit_object_filter OPTIONAL
      RAISING
        zcx_abapgit_exception.

  PROTECTED SECTION.

  PRIVATE SECTION.

    DATA mi_repo TYPE REF TO zif_abapgit_repo .
    DATA mi_obj_filter TYPE REF TO zif_abapgit_object_filter .
    DATA mo_form_data TYPE REF TO zcl_abapgit_string_map .
    DATA ms_checks TYPE zif_abapgit_definitions=>ty_deserialize_checks .

    METHODS pull
      RAISING
        zcx_abapgit_exception .
    METHODS form
      RETURNING
        VALUE(ro_form) TYPE REF TO zcl_abapgit_html_form
      RAISING
        zcx_abapgit_exception .
    METHODS choose_transport_request
      RAISING
        zcx_abapgit_exception .
ENDCLASS.



CLASS zcl_abapgit_gui_page_pull IMPLEMENTATION.


  METHOD choose_transport_request.

    DATA lv_transport_request TYPE trkorr.

    lv_transport_request = zcl_abapgit_ui_factory=>get_popups( )->popup_transport_request( ).

    IF lv_transport_request IS NOT INITIAL.
      mo_form_data->set(
        iv_key = c_id-transport_request
        iv_val = lv_transport_request ).
    ENDIF.

  ENDMETHOD.


  METHOD constructor.

    super->constructor( ).

    mi_repo       = ii_repo.
    mi_obj_filter = ii_obj_filter.

    mo_form_data = NEW #( ).
    mo_form_data->set(
      iv_key = c_id-transport_request
      iv_val = iv_trkorr ).

  ENDMETHOD.


  METHOD create.

    DATA lo_component TYPE REF TO zcl_abapgit_gui_page_pull.

    lo_component = NEW #( ii_repo = ii_repo
                          iv_trkorr = iv_trkorr
                          ii_obj_filter = ii_obj_filter ).

    ri_page = zcl_abapgit_gui_page_hoc=>create(
      iv_page_title         = 'Pull'
      ii_page_menu_provider = lo_component
      ii_child_component    = lo_component ).

  ENDMETHOD.


  METHOD form.

    DATA lt_filter TYPE zif_abapgit_definitions=>ty_tadir_tt.

    FIELD-SYMBOLS <ls_overwrite> LIKE LINE OF ms_checks-overwrite.


    IF mi_obj_filter IS NOT INITIAL.
      lt_filter = mi_obj_filter->get_filter( ).
    ENDIF.

    ro_form = zcl_abapgit_html_form=>create( iv_form_id = 'pull-form' ).

    ro_form->start_group(
      iv_name  = 'id-objects'
      iv_label = 'Objects' ).

    LOOP AT ms_checks-overwrite ASSIGNING <ls_overwrite>.
      IF lines( lt_filter ) > 0.
        READ TABLE lt_filter WITH KEY object = <ls_overwrite>-obj_type
          obj_name = <ls_overwrite>-obj_name TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
      ENDIF.
      ro_form->checkbox(
        iv_label = |{ <ls_overwrite>-obj_type } { <ls_overwrite>-obj_name }|
        iv_name  = |{ <ls_overwrite>-obj_type }-{ <ls_overwrite>-obj_name }| ).
    ENDLOOP.

    ro_form->text(
      iv_name        = c_id-transport_request
      iv_required    = abap_true
      iv_upper_case  = abap_true
      iv_side_action = c_action-choose_tr
      iv_max         = 10
      iv_label       = |Transport Request| ).

    ro_form->command(
      iv_label    = 'Pull'
      iv_cmd_type = zif_abapgit_html_form=>c_cmd_type-input_main
      iv_action   = c_action-pull
    )->command(
      iv_label    = 'Back'
      iv_action   = zif_abapgit_definitions=>c_action-go_back ).

  ENDMETHOD.


  METHOD pull.

    DATA lv_value TYPE string.

    FIELD-SYMBOLS <ls_overwrite> LIKE LINE OF ms_checks-overwrite.
    FIELD-SYMBOLS <ls_warning> LIKE LINE OF ms_checks-warning_package.


    ms_checks-transport-transport = mo_form_data->get( c_id-transport_request ).

    LOOP AT ms_checks-overwrite ASSIGNING <ls_overwrite>.
      lv_value = mo_form_data->get( |{ <ls_overwrite>-obj_type }-{ <ls_overwrite>-obj_name }| ).
      IF lv_value = 'on'.
        <ls_overwrite>-decision = zif_abapgit_definitions=>c_yes.
      ELSE.
        <ls_overwrite>-decision = zif_abapgit_definitions=>c_no.
      ENDIF.
    ENDLOOP.

    LOOP AT ms_checks-warning_package ASSIGNING <ls_warning>.
      lv_value = mo_form_data->get( |{ <ls_warning>-obj_type }-{ <ls_warning>-obj_name }| ).
      IF lv_value = 'on'.
        <ls_warning>-decision = zif_abapgit_definitions=>c_yes.
      ELSE.
        <ls_warning>-decision = zif_abapgit_definitions=>c_no.
      ENDIF.
    ENDLOOP.

* todo, show log?
    zcl_abapgit_services_repo=>real_deserialize(
      is_checks = ms_checks
      ii_repo   = mi_repo ).

  ENDMETHOD.


  METHOD zif_abapgit_gui_event_handler~on_event.

    mo_form_data->merge( ii_event->form_data( ) ).

    CASE ii_event->mv_action.
      WHEN c_action-refresh.
        mi_repo->refresh( ).
        rs_handled-state = zcl_abapgit_gui=>c_event_state-re_render.
      WHEN c_action-choose_tr.
        choose_transport_request( ).
        rs_handled-state = zcl_abapgit_gui=>c_event_state-re_render.
      WHEN c_action-pull.
        pull( ).
        rs_handled-state = zcl_abapgit_gui=>c_event_state-go_back.
    ENDCASE.

  ENDMETHOD.


  METHOD zif_abapgit_gui_menu_provider~get_menu.

    ro_toolbar = zcl_abapgit_html_toolbar=>create( 'toolbar-pull' ).

    ro_toolbar->add(
      iv_txt = 'Refresh'
      iv_act = c_action-refresh ).

    ro_toolbar->add(
      iv_txt = 'Back'
      iv_act = zif_abapgit_definitions=>c_action-go_back ).

  ENDMETHOD.


  METHOD zif_abapgit_gui_renderable~render.

    register_handlers( ).

    ri_html = NEW zcl_abapgit_html( ).
    ri_html->add( '<div class="repo-overview">' ).

    ms_checks = mi_repo->deserialize_checks( ).

    IF lines( ms_checks-overwrite ) = 0.
      zcx_abapgit_exception=>raise(
        'There is nothing to pull. The local state completely matches the remote repository.' ).
    ENDIF.

    ri_html->add( form( )->render( mo_form_data ) ).

    ri_html->add( '</div>' ).

  ENDMETHOD.
ENDCLASS.
