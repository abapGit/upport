CLASS zcl_abapgit_gui_page_flow DEFINITION
  PUBLIC
  INHERITING FROM zcl_abapgit_gui_component
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.

    INTERFACES zif_abapgit_gui_event_handler .
    INTERFACES zif_abapgit_gui_renderable .
    INTERFACES zif_abapgit_gui_menu_provider .

    CLASS-METHODS create
      RETURNING
        VALUE(ri_page) TYPE REF TO zif_abapgit_gui_renderable
      RAISING
        zcx_abapgit_exception .
    METHODS constructor
      RAISING
        zcx_abapgit_exception .
  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF c_action,
        refresh TYPE string VALUE 'refresh',
        pull    TYPE string VALUE 'pull',
        stage   TYPE string VALUE 'stage',
      END OF c_action .
    DATA mt_features TYPE zif_abapgit_gui_page_flow=>ty_features .

    METHODS refresh
      RAISING
        zcx_abapgit_exception .
    METHODS set_branch
      IMPORTING
        !iv_branch TYPE string
        !iv_key    TYPE zif_abapgit_persistence=>ty_value
      RAISING
        zcx_abapgit_exception .
    METHODS render_table
      IMPORTING
        !is_feature    TYPE zif_abapgit_gui_page_flow=>ty_feature
      RETURNING
        VALUE(ri_html) TYPE REF TO zif_abapgit_html .
    METHODS render_toolbar
      IMPORTING
        !iv_index      TYPE i
        !is_feature    TYPE zif_abapgit_gui_page_flow=>ty_feature
      RETURNING
        VALUE(ri_html) TYPE REF TO zif_abapgit_html .
ENDCLASS.



CLASS zcl_abapgit_gui_page_flow IMPLEMENTATION.


  METHOD constructor.
    super->constructor( ).

  ENDMETHOD.


  METHOD create.

    DATA lo_component TYPE REF TO zcl_abapgit_gui_page_flow.

    lo_component = NEW #( ).

    ri_page = zcl_abapgit_gui_page_hoc=>create(
      iv_page_title         = 'Flow'
      ii_page_menu_provider = lo_component
      ii_child_component    = lo_component ).

  ENDMETHOD.


  METHOD refresh.

    DATA ls_feature LIKE LINE OF mt_features.
    DATA li_repo  TYPE REF TO zif_abapgit_repo.


    LOOP AT mt_features INTO ls_feature.
      li_repo = zcl_abapgit_repo_srv=>get_instance( )->get( ls_feature-repo-key ).
      li_repo->refresh( ).
    ENDLOOP.

    CLEAR mt_features.

  ENDMETHOD.


  METHOD render_table.

    DATA ls_path_name LIKE LINE OF is_feature-changed_files.
    DATA lv_status    TYPE string.
    DATA lv_branch    TYPE string.
    DATA lv_param     TYPE string.


    ri_html = NEW zcl_abapgit_html( ).

    ri_html->add( |<table>| ).
    ri_html->add( |<tr><td><u>Filename</u></td><td><u>Remote</u></td><td><u>Local</u></td><td></td></tr>| ).

    lv_branch = is_feature-branch-display_name.
    IF lv_branch IS INITIAL.
      lv_branch = 'main'.
    ENDIF.

    LOOP AT is_feature-changed_files INTO ls_path_name.
      IF ls_path_name-remote_sha1 = ls_path_name-local_sha1.
        lv_status = 'Match'.
      ELSE.
        ASSERT is_feature-repo-key IS NOT INITIAL.
        lv_param = zcl_abapgit_html_action_utils=>file_encode(
          iv_key   = is_feature-repo-key
          ig_file  = ls_path_name
          iv_extra = lv_branch ).
        lv_status = ri_html->a(
          iv_txt = 'Diff'
          iv_act = |{ zif_abapgit_definitions=>c_action-go_file_diff }?{ lv_param }| ).
      ENDIF.

      ri_html->add( |<tr><td><tt>{ ls_path_name-path }{ ls_path_name-filename }</tt></td><td>{
        ls_path_name-remote_sha1(7) }</td><td>{
        ls_path_name-local_sha1(7) }</td><td>{ lv_status }</td></tr>| ).
    ENDLOOP.
    ri_html->add( |</table>| ).

  ENDMETHOD.


  METHOD render_toolbar.

    DATA lo_toolbar TYPE REF TO zcl_abapgit_html_toolbar.
    DATA lv_extra TYPE string.

* todo: crossout pull if write protected

    ri_html = NEW zcl_abapgit_html( ).
    lo_toolbar = NEW #( iv_id = 'toolbar-flow' ).

    IF is_feature-full_match = abap_false.
      lv_extra = |?index={ iv_index }&key={ is_feature-repo-key }&branch={ is_feature-branch-display_name }|.
      lo_toolbar->add( iv_txt = 'Pull'
                       iv_act = |{ c_action-pull }{ lv_extra }|
                       iv_opt = zif_abapgit_html=>c_html_opt-strong ).
      lo_toolbar->add( iv_txt = 'Stage'
                       iv_act = |{ c_action-stage }{ lv_extra }|
                       iv_opt = zif_abapgit_html=>c_html_opt-strong ).
    ENDIF.

    zcl_abapgit_flow_exit=>get_instance( )->toolbar_extras(
      io_toolbar = lo_toolbar
      iv_index   = iv_index
      is_feature = is_feature ).

    ri_html->add( lo_toolbar->render( ) ).

  ENDMETHOD.


  METHOD set_branch.

    DATA lv_branch TYPE string.
    DATA li_repo_online TYPE REF TO zif_abapgit_repo_online.

    IF iv_branch IS NOT INITIAL.
      lv_branch = 'refs/heads/' && iv_branch.
      li_repo_online ?= zcl_abapgit_repo_srv=>get_instance( )->get( iv_key ).
      IF li_repo_online->get_selected_branch( ) <> lv_branch.
        li_repo_online->select_branch( lv_branch ).
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD zif_abapgit_gui_event_handler~on_event.

    DATA lv_key     TYPE zif_abapgit_persistence=>ty_value.
    DATA lv_branch  TYPE string.
    DATA lo_filter  TYPE REF TO lcl_filter.
    DATA lt_filter  TYPE zif_abapgit_definitions=>ty_tadir_tt.
    DATA lv_index   TYPE i.
    DATA li_repo_online  TYPE REF TO zif_abapgit_repo_online.
    DATA ls_feature LIKE LINE OF mt_features.
    DATA ls_event_result TYPE zif_abapgit_flow_exit=>ty_event_result.

    FIELD-SYMBOLS <ls_object> LIKE LINE OF ls_feature-changed_objects.
    FIELD-SYMBOLS <ls_filter> LIKE LINE OF lt_filter.


    CASE ii_event->mv_action.
      WHEN c_action-refresh.
        refresh( ).
        rs_handled-state = zcl_abapgit_gui=>c_event_state-re_render.
      WHEN zif_abapgit_definitions=>c_action-go_file_diff.
        lv_key = ii_event->query( )->get( 'KEY' ).
        lv_branch = ii_event->query( )->get( 'EXTRA' ).
        set_branch(
          iv_branch = lv_branch
          iv_key    = lv_key ).
* calling the page is done by the global router
      WHEN c_action-stage.
        lv_key = ii_event->query( )->get( 'KEY' ).
        lv_index = ii_event->query( )->get( 'INDEX' ).
        lv_branch = ii_event->query( )->get( 'BRANCH' ).
        li_repo_online ?= zcl_abapgit_repo_srv=>get_instance( )->get( lv_key ).

        READ TABLE mt_features INTO ls_feature INDEX lv_index.
        ASSERT sy-subrc = 0.

        LOOP AT ls_feature-changed_objects ASSIGNING <ls_object>.
          APPEND INITIAL LINE TO lt_filter ASSIGNING <ls_filter>.
          <ls_filter>-object = <ls_object>-obj_type.
          <ls_filter>-obj_name = <ls_object>-obj_name.
        ENDLOOP.
        lo_filter = NEW #( it_filter = lt_filter ).

        set_branch(
          iv_branch = lv_branch
          iv_key    = lv_key ).

        rs_handled-page = zcl_abapgit_gui_page_stage=>create(
          ii_force_refresh = abap_false
          ii_repo_online   = li_repo_online
          ii_obj_filter    = lo_filter ).

        rs_handled-state = zcl_abapgit_gui=>c_event_state-new_page_w_bookmark.

        refresh( ).
      WHEN c_action-pull.
        lv_key = ii_event->query( )->get( 'KEY' ).
        lv_index = ii_event->query( )->get( 'INDEX' ).
        lv_branch = ii_event->query( )->get( 'BRANCH' ).
        li_repo_online ?= zcl_abapgit_repo_srv=>get_instance( )->get( lv_key ).

        READ TABLE mt_features INTO ls_feature INDEX lv_index.
        ASSERT sy-subrc = 0.

        LOOP AT ls_feature-changed_objects ASSIGNING <ls_object>.
          APPEND INITIAL LINE TO lt_filter ASSIGNING <ls_filter>.
          <ls_filter>-object = <ls_object>-obj_type.
          <ls_filter>-obj_name = <ls_object>-obj_name.
        ENDLOOP.
        lo_filter = NEW #( it_filter = lt_filter ).

        set_branch(
          iv_branch = lv_branch
          iv_key    = lv_key ).

        rs_handled-page = zcl_abapgit_gui_page_pull=>create(
          ii_repo       = li_repo_online
          iv_trkorr     = ls_feature-transport-trkorr
          ii_obj_filter = lo_filter ).

        rs_handled-state = zcl_abapgit_gui=>c_event_state-new_page.

        refresh( ).
      WHEN OTHERS.
        ls_event_result = zcl_abapgit_flow_exit=>get_instance( )->on_event(
         ii_event    = ii_event
         it_features = mt_features ).

        rs_handled = ls_event_result-handled.

        IF ls_event_result-refresh = abap_true.
          refresh( ).
        ENDIF.
    ENDCASE.

  ENDMETHOD.


  METHOD zif_abapgit_gui_menu_provider~get_menu.

    ro_toolbar = zcl_abapgit_html_toolbar=>create( 'toolbar-flow' ).

    ro_toolbar->add(
      iv_txt = 'Refresh'
      iv_act = c_action-refresh ).

    ro_toolbar->add(
      iv_txt = zcl_abapgit_gui_buttons=>repo_list( )
      iv_act = zif_abapgit_definitions=>c_action-abapgit_home ).

    ro_toolbar->add(
      iv_txt = 'Back'
      iv_act = zif_abapgit_definitions=>c_action-go_back ).

  ENDMETHOD.


  METHOD zif_abapgit_gui_renderable~render.

    DATA ls_feature  LIKE LINE OF mt_features.
    DATA lv_index    TYPE i.
    DATA lv_rendered TYPE abap_bool.


    register_handlers( ).
    ri_html = NEW zcl_abapgit_html( ).
    ri_html->add( '<div class="repo-overview">' ).

    IF mt_features IS INITIAL.
      mt_features = zcl_abapgit_flow_logic=>get_information( ).
    ENDIF.

    LOOP AT mt_features INTO ls_feature.
      lv_index = sy-tabix.

      IF lines( ls_feature-changed_files ) = 0.
* no changes, eg. only files outside of starting folder changed
        CONTINUE.
      ENDIF.
      lv_rendered = abap_true.

      ri_html->add( '<b><font size="+2">' && ls_feature-repo-name ).
      IF ls_feature-branch-display_name IS NOT INITIAL.
        ri_html->add( | - | ).
        ri_html->add_icon( 'code-branch' ).
        ri_html->add( ls_feature-branch-display_name ).
      ENDIF.
      IF ls_feature-transport-trkorr IS NOT INITIAL.
        ri_html->add( | - | ).
        ri_html->add_icon( 'truck-solid' ).
        ri_html->add( |<tt>{ ls_feature-transport-trkorr }</tt>| ).
      ENDIF.
      ri_html->add( |</font></b><br>| ).

      IF ls_feature-branch-display_name IS INITIAL.
        ri_html->add( |No branch found, comparing with <tt>main</tt>| ).
      ELSEIF ls_feature-pr IS NOT INITIAL.
        ri_html->add_a(
          iv_txt   = ls_feature-pr-title
          iv_act   = |{ zif_abapgit_definitions=>c_action-url }?url={ ls_feature-pr-url }|
          iv_class = |url| ).

        IF ls_feature-pr-draft = abap_true.
          ri_html->add( 'DRAFT' ).
        ENDIF.
      ELSE.
        ri_html->add( |No PR found| ).
      ENDIF.
      ri_html->add( |<br>| ).

      IF ls_feature-transport IS NOT INITIAL.
        ri_html->add( |<tt>{ ls_feature-transport-trkorr }</tt> - { ls_feature-transport-title }<br>| ).
      ELSE.
        ri_html->add( |No corresponding transport found<br>| ).
      ENDIF.

      IF ls_feature-branch IS NOT INITIAL AND ls_feature-branch-up_to_date = abap_false.
        ri_html->add( '<b>Branch not up to date</b><br><br>' ).
        CONTINUE.
      ENDIF.

      ri_html->add( render_toolbar(
        iv_index   = lv_index
        is_feature = ls_feature ) ).

      IF ls_feature-full_match = abap_true.
        ri_html->add( |Full Match<br>| ).
      ELSE.
        ri_html->add( render_table( ls_feature ) ).
      ENDIF.

* todo      LOOP AT ls_feature-changed_objects INTO ls_item.
* todo       ri_html->add( |<tt><small>{ ls_item-obj_type } { ls_item-obj_name }</small></tt><br>| ).
* todo     ENDLOOP.

      ri_html->add( '<br>' ).
    ENDLOOP.

    IF lines( mt_features ) = 0 OR lv_rendered = abap_false.
      ri_html->add( 'Empty, repositories must be favorite + flow enabled<br><br>' ).

      ri_html->add( 'Or nothing in progress<br><br>' ).

      ri_html->add_a(
        iv_txt   = 'abapGit flow documentation'
        iv_act   = |{ zif_abapgit_definitions=>c_action-url
          }?url=https://docs.abapgit.org/user-guide/reference/flow.html|
        iv_class = |url| ).
    ENDIF.

    ri_html->add( '</div>' ).

  ENDMETHOD.
ENDCLASS.
