CLASS zcl_abapgit_gui_page_stage DEFINITION
  PUBLIC
  INHERITING FROM zcl_abapgit_gui_component
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    INTERFACES:
      zif_abapgit_gui_event_handler,
      zif_abapgit_gui_hotkeys,
      zif_abapgit_gui_menu_provider,
      zif_abapgit_gui_renderable.

    CONSTANTS: BEGIN OF c_action,
                 stage_refresh TYPE string VALUE 'stage_refresh',
                 stage_all     TYPE string VALUE 'stage_all',
                 stage_commit  TYPE string VALUE 'stage_commit',
                 stage_filter  TYPE string VALUE 'stage_filter',
               END OF c_action.

    CLASS-METHODS create
      IMPORTING
        ii_repo_online   TYPE REF TO zif_abapgit_repo_online
        iv_seed          TYPE string OPTIONAL
        iv_sci_result    TYPE zif_abapgit_definitions=>ty_sci_result DEFAULT zif_abapgit_definitions=>c_sci_result-no_run
        ii_obj_filter    TYPE REF TO zif_abapgit_object_filter OPTIONAL
        ii_force_refresh TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(ri_page)   TYPE REF TO zif_abapgit_gui_renderable
      RAISING
        zcx_abapgit_exception.

    METHODS constructor
      IMPORTING
        ii_repo_online   TYPE REF TO zif_abapgit_repo_online
        iv_seed          TYPE string OPTIONAL
        iv_sci_result    TYPE zif_abapgit_definitions=>ty_sci_result DEFAULT zif_abapgit_definitions=>c_sci_result-no_run
        ii_obj_filter    TYPE REF TO zif_abapgit_object_filter OPTIONAL
        ii_force_refresh TYPE abap_bool DEFAULT abap_true
      RAISING
        zcx_abapgit_exception.

  PROTECTED SECTION.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_changed_by,
        item     TYPE zif_abapgit_definitions=>ty_item,
        filename TYPE string,
        name     TYPE syuname,
      END OF ty_changed_by .
    TYPES:
      ty_changed_by_tt TYPE SORTED TABLE OF ty_changed_by WITH UNIQUE KEY item filename.

    DATA mi_repo TYPE REF TO zif_abapgit_repo.
    DATA mi_repo_online TYPE REF TO zif_abapgit_repo_online.
    DATA ms_files TYPE zif_abapgit_definitions=>ty_stage_files .
    DATA mv_seed TYPE string .               " Unique page id to bind JS sessionStorage
    DATA mv_filter_value TYPE string .
    DATA mv_sci_result TYPE zif_abapgit_definitions=>ty_sci_result.
    DATA mi_obj_filter TYPE REF TO zif_abapgit_object_filter.

    METHODS find_changed_by
      IMPORTING
        !it_files            TYPE zif_abapgit_definitions=>ty_stage_files
        !it_transports       TYPE zif_abapgit_cts_api=>ty_transport_list
      RETURNING
        VALUE(rt_changed_by) TYPE ty_changed_by_tt .
    METHODS find_transports
      IMPORTING
        !it_files            TYPE zif_abapgit_definitions=>ty_stage_files
      RETURNING
        VALUE(rt_transports) TYPE zif_abapgit_cts_api=>ty_transport_list .
    METHODS render_list
      RETURNING
        VALUE(ri_html) TYPE REF TO zif_abapgit_html
      RAISING
        zcx_abapgit_exception .
    METHODS render_file
      IMPORTING
        !iv_context    TYPE string
        !is_file       TYPE zif_abapgit_git_definitions=>ty_file
        !is_item       TYPE zif_abapgit_definitions=>ty_item OPTIONAL
        !is_status     TYPE zif_abapgit_definitions=>ty_result
        !iv_changed_by TYPE syuname OPTIONAL
        !iv_transport  TYPE trkorr OPTIONAL
      RETURNING
        VALUE(ri_html) TYPE REF TO zif_abapgit_html
      RAISING
        zcx_abapgit_exception .
    METHODS render_actions
      RETURNING
        VALUE(ri_html) TYPE REF TO zif_abapgit_html .
    METHODS stage_selected
      IMPORTING
        !ii_event       TYPE REF TO zif_abapgit_gui_event
      RETURNING
        VALUE(ro_stage) TYPE REF TO zcl_abapgit_stage
      RAISING
        zcx_abapgit_exception .
    METHODS stage_all
      RETURNING
        VALUE(ro_stage) TYPE REF TO zcl_abapgit_stage
      RAISING
        zcx_abapgit_exception .
    METHODS get_page_patch
      IMPORTING
        !io_stage      TYPE REF TO zcl_abapgit_stage
      RETURNING
        VALUE(ri_page) TYPE REF TO zif_abapgit_gui_renderable
      RAISING
        zcx_abapgit_exception .
    METHODS render_main_language_warning
      RETURNING
        VALUE(ri_html) TYPE REF TO zif_abapgit_html .
    METHODS count_default_files_to_commit
      RETURNING
        VALUE(rv_count) TYPE i .
    METHODS render_deferred_hidden_events
      RETURNING
        VALUE(ri_html) TYPE REF TO zif_abapgit_html .
    METHODS render_scripts
      RETURNING
        VALUE(ri_html) TYPE REF TO zif_abapgit_html
      RAISING
        zcx_abapgit_exception .
    METHODS init_files
      RAISING
        zcx_abapgit_exception .
ENDCLASS.



CLASS zcl_abapgit_gui_page_stage IMPLEMENTATION.


  METHOD constructor.

    DATA lv_ts TYPE timestamp.

    super->constructor( ).

    mi_repo        = ii_repo_online.
    mi_repo_online = ii_repo_online.
    mv_seed        = iv_seed.
    mv_sci_result  = iv_sci_result.
    mi_obj_filter  = ii_obj_filter.

    " force refresh on stage, to make sure the latest local and remote files are used
    IF ii_force_refresh = abap_true.
      ii_repo_online->zif_abapgit_repo~refresh( ).
    ENDIF.

    IF mv_seed IS INITIAL. " Generate based on time unless obtained from diff page
      GET TIME STAMP FIELD lv_ts.
      mv_seed = |stage{ lv_ts }|.
    ENDIF.

    init_files( ).

  ENDMETHOD.


  METHOD count_default_files_to_commit.

    FIELD-SYMBOLS <ls_status> LIKE LINE OF ms_files-status.
    FIELD-SYMBOLS <ls_remote> LIKE LINE OF ms_files-remote.

    rv_count = lines( ms_files-local ).

    LOOP AT ms_files-remote ASSIGNING <ls_remote>.
      READ TABLE ms_files-status ASSIGNING <ls_status>
        WITH TABLE KEY
          path     = <ls_remote>-path
          filename = <ls_remote>-filename.
      ASSERT sy-subrc = 0.

      IF <ls_status>-lstate = zif_abapgit_definitions=>c_state-deleted
        AND <ls_status>-rstate = zif_abapgit_definitions=>c_state-unchanged.
        rv_count = rv_count + 1.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD create.

    DATA lo_component TYPE REF TO zcl_abapgit_gui_page_stage.

    lo_component = NEW #( ii_repo_online = ii_repo_online
                          iv_seed = iv_seed
                          iv_sci_result = iv_sci_result
                          ii_force_refresh = ii_force_refresh
                          ii_obj_filter = ii_obj_filter ).

    ri_page = zcl_abapgit_gui_page_hoc=>create(
      iv_page_title         = 'Stage'
      ii_page_menu_provider = lo_component
      ii_child_component    = lo_component ).

  ENDMETHOD.


  METHOD find_changed_by.

    DATA: ls_local             LIKE LINE OF it_files-local,
          ls_remote            LIKE LINE OF it_files-remote,
          ls_changed_by        LIKE LINE OF rt_changed_by,
          lt_changed_by_remote LIKE rt_changed_by,
          ls_item              TYPE zif_abapgit_definitions=>ty_item,
          lv_transport         LIKE LINE OF it_transports,
          lv_user              TYPE uname.

    FIELD-SYMBOLS <ls_changed_by> LIKE LINE OF lt_changed_by_remote.

    LOOP AT it_files-local INTO ls_local WHERE NOT item IS INITIAL.
      ls_changed_by-item = ls_local-item.
      ls_changed_by-filename = ls_local-file-filename.
      ls_changed_by-name = zcl_abapgit_objects=>changed_by(
        is_item     = ls_local-item
        iv_filename = ls_local-file-filename ).
      INSERT ls_changed_by INTO TABLE rt_changed_by.
    ENDLOOP.

    LOOP AT it_files-remote INTO ls_remote WHERE filename IS NOT INITIAL.
      TRY.
          zcl_abapgit_filename_logic=>file_to_object(
            EXPORTING
              iv_filename = ls_remote-filename
              iv_path     = ls_remote-path
              io_dot      = mi_repo->get_dot_abapgit( )
            IMPORTING
              es_item     = ls_item ).
          ls_changed_by-item = ls_item.
          INSERT ls_changed_by INTO TABLE lt_changed_by_remote.
        CATCH zcx_abapgit_exception ##NO_HANDLER.
      ENDTRY.
    ENDLOOP.

    LOOP AT lt_changed_by_remote ASSIGNING <ls_changed_by>.
      " deleted files might still be in a transport
      CLEAR lv_transport.
      READ TABLE it_transports WITH KEY
        obj_type = <ls_changed_by>-item-obj_type
        obj_name = <ls_changed_by>-item-obj_name
        INTO lv_transport.
      IF sy-subrc = 0.
        lv_user = zcl_abapgit_factory=>get_cts_api( )->read_user( lv_transport-trkorr ).
        IF lv_user IS NOT INITIAL.
          <ls_changed_by>-name = lv_user.
        ENDIF.
      ENDIF.
      IF <ls_changed_by>-name IS INITIAL.
        <ls_changed_by>-name = zcl_abapgit_objects_super=>c_user_unknown.
      ENDIF.
    ENDLOOP.

    INSERT LINES OF lt_changed_by_remote INTO TABLE rt_changed_by.

  ENDMETHOD.


  METHOD find_transports.

    DATA li_cts_api TYPE REF TO zif_abapgit_cts_api.
    DATA lt_items TYPE zif_abapgit_definitions=>ty_items_tt.
    DATA ls_item TYPE zif_abapgit_definitions=>ty_item.
    DATA lo_dot TYPE REF TO zcl_abapgit_dot_abapgit.
    FIELD-SYMBOLS <ls_local> LIKE LINE OF it_files-local.
    FIELD-SYMBOLS <ls_remote> LIKE LINE OF it_files-remote.


    li_cts_api = zcl_abapgit_factory=>get_cts_api( ).

    TRY.
        LOOP AT it_files-local ASSIGNING <ls_local> WHERE item IS NOT INITIAL.
          IF li_cts_api->is_chrec_possible_for_package( <ls_local>-item-devclass ) = abap_false.
            RETURN. " Assume all other objects are also in packages without change recording
          ENDIF.
          APPEND <ls_local>-item TO lt_items.
        ENDLOOP.

        lo_dot = mi_repo->get_dot_abapgit( ).
        LOOP AT it_files-remote ASSIGNING <ls_remote> WHERE filename IS NOT INITIAL.
          zcl_abapgit_filename_logic=>file_to_object(
            EXPORTING
              iv_filename = <ls_remote>-filename
              iv_path     = <ls_remote>-path
              io_dot      = lo_dot
            IMPORTING
              es_item     = ls_item ).
          IF ls_item IS INITIAL.
            CONTINUE.
          ENDIF.
          APPEND ls_item TO lt_items.
        ENDLOOP.

        SORT lt_items BY obj_type obj_name.
        DELETE ADJACENT DUPLICATES FROM lt_items COMPARING obj_type obj_name.

        rt_transports = li_cts_api->get_transports_for_list( lt_items ).

      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.

  ENDMETHOD.


  METHOD get_page_patch.

    DATA: lv_key   TYPE zif_abapgit_persistence=>ty_repo-key,
          lt_files TYPE zif_abapgit_definitions=>ty_stage_tt.

    lv_key = mi_repo->get_key( ).
    lt_files = io_stage->get_all( ).

    DELETE lt_files WHERE method <> zif_abapgit_definitions=>c_method-add
                      AND method <> zif_abapgit_definitions=>c_method-rm.

    ri_page  = zcl_abapgit_gui_page_patch=>create(
      iv_key   = lv_key
      it_files = lt_files ).

  ENDMETHOD.


  METHOD init_files.
    ms_files = zcl_abapgit_stage_logic=>get_stage_logic( )->get( ii_repo_online = mi_repo_online
                                                                 ii_obj_filter  = mi_obj_filter ).

    IF lines( ms_files-local ) = 0 AND lines( ms_files-remote ) = 0.
      mi_repo->refresh( ).
      zcx_abapgit_exception=>raise( 'There are no changes that could be staged' ).
    ENDIF.
  ENDMETHOD.


  METHOD render_actions.

    DATA: lv_local_count TYPE i,
          lv_add_all_txt TYPE string.

    ri_html = NEW zcl_abapgit_html( ).
    lv_local_count = count_default_files_to_commit( ).
    IF lv_local_count > 0.
      lv_add_all_txt = |Add All and Commit ({ lv_local_count })|.
      " Otherwise empty, but the element (id) is preserved for JS
    ENDIF.

    ri_html->add( '<table class="w100 margin-v5"><tr>' ).

    " Action buttons
    ri_html->add( '<td class="indent5em">' ).
    ri_html->add_a( iv_act   = 'errorStub(event)' " Will be reinit by JS
                    iv_typ   = zif_abapgit_html=>c_action_type-onclick
                    iv_id    = 'commitSelectedButton'
                    iv_style = 'display: none'
                    iv_txt   = 'Commit Selected (<span class="counter"></span>)'
                    iv_opt   = zif_abapgit_html=>c_html_opt-strong ).
    ri_html->add_a( iv_act   = 'errorStub(event)' " Will be reinit by JS
                    iv_typ   = zif_abapgit_html=>c_action_type-onclick
                    iv_id    = 'commitFilteredButton'
                    iv_style = 'display: none'
                    iv_txt   = 'Add <b>Filtered</b> and Commit (<span class="counter"></span>)' ).
    ri_html->add_a( iv_act = |{ c_action-stage_all }|
                    iv_id  = 'commitAllButton'
                    iv_txt = lv_add_all_txt ).


    ri_html->add( '</td>' ).

    " Filter bar
    ri_html->add( '<td class="right">' ).
    ri_html->add( '<input class="stage-filter" id="objectSearch"' &&
                  ' type="search" placeholder="Filter Objects"' &&
                  | value="{ mv_filter_value }">| ).
    zcl_abapgit_gui_chunk_lib=>render_sci_result(
      ii_html       = ri_html
      iv_sci_result = mv_sci_result ).
    ri_html->add( '</td>' ).

    ri_html->add( '</tr>' ).
    ri_html->add( '</table>' ).

  ENDMETHOD.


  METHOD render_deferred_hidden_events.

    DATA ls_event TYPE zcl_abapgit_gui_chunk_lib=>ty_event_signature.

    ls_event-method = 'post'.
    ls_event-name   = 'stage_commit'.
    ri_html = zcl_abapgit_gui_chunk_lib=>render_event_as_form( ls_event ).
    ri_html->set_title( cl_abap_typedescr=>describe_by_object_ref( me )->get_relative_name( ) ).

  ENDMETHOD.


  METHOD render_file.

    DATA: lv_param    TYPE string,
          lv_filename TYPE string.

    ri_html = NEW zcl_abapgit_html( ).

    lv_filename = is_file-path && is_file-filename.
    " make sure whitespace is preserved in the DOM
    REPLACE ALL OCCURRENCES OF ` ` IN lv_filename WITH '&nbsp;'.

    ri_html->add( |<tr class="{ iv_context }">| ).
    ri_html->add( '<td>' ).
    ri_html->add( zcl_abapgit_gui_chunk_lib=>render_item_state(
      iv_lstate = is_status-lstate
      iv_rstate = is_status-rstate ) ).
    ri_html->add( '</td>' ).

    CASE iv_context.
      WHEN 'local'.
        lv_param = zcl_abapgit_html_action_utils=>file_encode(
          iv_key  = mi_repo->get_key( )
          ig_file = is_file ).

        lv_filename = ri_html->a(
          iv_txt = lv_filename
          iv_act = |{ zif_abapgit_definitions=>c_action-go_file_diff }?{ lv_param }| ).

        ri_html->add( |<td class="type">{ is_item-obj_type }</td>| ).
        ri_html->add( |<td class="name">{ lv_filename }</td>| ).
      WHEN 'remote'.
        ri_html->add( |<td class="type">{ is_item-obj_type }</td>| ).
        ri_html->add( |<td class="name">{ lv_filename }</td>| ).
    ENDCASE.

    ri_html->add( '<td class="user">' ).
    ri_html->add( zcl_abapgit_gui_chunk_lib=>render_user_name( iv_changed_by ) ).
    ri_html->add( '</td>' ).

    ri_html->add( '<td class="transport">' ).
    ri_html->add( zcl_abapgit_gui_chunk_lib=>render_transport(
      iv_transport = iv_transport
      iv_obj_type  = is_item-obj_type
      iv_obj_name  = is_item-obj_name ) ).
    ri_html->add( '</td>' ).

    ri_html->add( '<td class="status">?</td>' ).
    ri_html->add( '<td class="cmd"></td>' ). " Command added in JS

    ri_html->add( '</tr>' ).

  ENDMETHOD.


  METHOD render_list.

    DATA: lt_changed_by  TYPE ty_changed_by_tt,
          ls_changed_by  LIKE LINE OF lt_changed_by,
          lt_transports  TYPE zif_abapgit_cts_api=>ty_transport_list,
          ls_transport   LIKE LINE OF lt_transports,
          ls_item_remote TYPE zif_abapgit_definitions=>ty_item.

    FIELD-SYMBOLS: <ls_remote> LIKE LINE OF ms_files-remote,
                   <ls_status> LIKE LINE OF ms_files-status,
                   <ls_local>  LIKE LINE OF ms_files-local.

    ri_html = NEW zcl_abapgit_html( ).

    ri_html->add( '<table id="stageTab" class="stage_tab w100">' ).

    lt_transports = find_transports( ms_files ).
    lt_changed_by = find_changed_by(
      it_files = ms_files
      it_transports = lt_transports ).

    " Local changes
    LOOP AT ms_files-local ASSIGNING <ls_local>.
      AT FIRST.
        ri_html->add( '<thead><tr class="local">' ).
        ri_html->add( '<th class="stage-status"></th>' ). " Diff state
        ri_html->add( '<th class="stage-objtype">Type</th>' ).
        ri_html->add( '<th title="Click filename to see diff">File</th>' ).
        ri_html->add( '<th>Changed by</th>' ).
        ri_html->add( '<th>Transport</th>' ).
        ri_html->add( '<th></th>' ). " Status
        ri_html->add( '<th class="cmd">' ).
        ri_html->add( '<a>add</a>&#x2193; <a>reset</a>&#x2193;' ).
        ri_html->add( '</th>' ).
        ri_html->add( '</tr></thead>' ).
        ri_html->add( '<tbody>' ).
      ENDAT.

      READ TABLE lt_changed_by INTO ls_changed_by WITH TABLE KEY
        item     = <ls_local>-item
        filename = <ls_local>-file-filename.
      IF sy-subrc <> 0.
        READ TABLE lt_changed_by INTO ls_changed_by WITH KEY item = <ls_local>-item.
      ENDIF.

      READ TABLE lt_transports INTO ls_transport WITH KEY
        obj_type = <ls_local>-item-obj_type
        obj_name = <ls_local>-item-obj_name.              "#EC CI_SUBRC
      READ TABLE ms_files-status ASSIGNING <ls_status>
        WITH TABLE KEY
          path     = <ls_local>-file-path
          filename = <ls_local>-file-filename.
      ASSERT sy-subrc = 0.

      ri_html->add( render_file(
        iv_context    = 'local'
        is_file       = <ls_local>-file
        is_item       = <ls_local>-item
        is_status     = <ls_status>
        iv_changed_by = ls_changed_by-name
        iv_transport  = ls_transport-trkorr ) ).

      CLEAR ls_transport.

      AT LAST.
        ri_html->add( '</tbody>' ).
      ENDAT.
    ENDLOOP.

    " Remote changes
    LOOP AT ms_files-remote ASSIGNING <ls_remote>.
      AT FIRST.
        ri_html->add( '<thead><tr class="remote">' ).
        ri_html->add( '<th></th>' ). " Diff state
        ri_html->add( '<th></th>' ). " Type
        ri_html->add( '<th colspan="3">Files to remove or non-code</th>' ).
        ri_html->add( '<th></th>' ). " Transport
        ri_html->add( '<th class="cmd">' ).
        ri_html->add( '<a>ignore</a>&#x2193; <a>remove</a>&#x2193; <a>reset</a>&#x2193;' ).
        ri_html->add( '</th>' ).
        ri_html->add( '</tr></thead>' ).
        ri_html->add( '<tbody>' ).
      ENDAT.

      READ TABLE ms_files-status ASSIGNING <ls_status>
        WITH TABLE KEY
          path     = <ls_remote>-path
          filename = <ls_remote>-filename.
      ASSERT sy-subrc = 0.

      TRY.
          zcl_abapgit_filename_logic=>file_to_object(
            EXPORTING
              iv_filename = <ls_remote>-filename
              iv_path     = <ls_remote>-path
              io_dot      = mi_repo->get_dot_abapgit( )
            IMPORTING
              es_item     = ls_item_remote ).
          READ TABLE lt_transports INTO ls_transport WITH KEY
            obj_type = ls_item_remote-obj_type
            obj_name = ls_item_remote-obj_name.

          READ TABLE lt_changed_by INTO ls_changed_by WITH TABLE KEY
            item     = ls_item_remote
            filename = <ls_remote>-filename.
          IF sy-subrc <> 0.
            READ TABLE lt_changed_by INTO ls_changed_by WITH KEY item = ls_item_remote.
          ENDIF.
        CATCH zcx_abapgit_exception.
          CLEAR ls_transport.
      ENDTRY.

      ri_html->add( render_file(
        iv_context    = 'remote'
        is_status     = <ls_status>
        is_file       = <ls_remote>
        is_item       = ls_item_remote
        iv_changed_by = ls_changed_by-name
        iv_transport  = ls_transport-trkorr ) ).

      AT LAST.
        ri_html->add( '</tbody>' ).
      ENDAT.
    ENDLOOP.

    ri_html->add( '</table>' ).

  ENDMETHOD.


  METHOD render_main_language_warning.

    DATA lv_main_language TYPE spras.

    ri_html = NEW zcl_abapgit_html( ).

    lv_main_language = mi_repo->get_dot_abapgit( )->get_main_language( ).

    IF lv_main_language <> sy-langu.
      ri_html->add( zcl_abapgit_gui_chunk_lib=>render_warning_banner(
                        |Caution: Main language of the repo is '{ lv_main_language }', |
                     && |but you're logged on in '{ sy-langu }'| ) ).
    ENDIF.

  ENDMETHOD.


  METHOD render_scripts.

    ri_html = NEW zcl_abapgit_html( ).

    ri_html->set_title( cl_abap_typedescr=>describe_by_object_ref( me )->get_relative_name( ) ).

    ri_html->add( 'var gStageParams = {' ).
    ri_html->add( |  seed:            "{ mv_seed }",| ). " Unique page id
    ri_html->add( |  user:            "{ to_lower( sy-uname ) }",| ).
    ri_html->add( '  formAction:      "stage_commit",' ).
    ri_html->add( |  patchAction:     "{ zif_abapgit_definitions=>c_action-go_patch }",| ).
    ri_html->add( '  focusFilterKey:  "f",' ).

    ri_html->add( '  ids: {' ).
    ri_html->add( '    stageTab:          "stageTab",' ).
    ri_html->add( '    commitAllBtn:      "commitAllButton",' ).
    ri_html->add( '    commitSelectedBtn: "commitSelectedButton",' ).
    ri_html->add( '    commitFilteredBtn: "commitFilteredButton",' ).
    ri_html->add( '    patchBtn:          "patchBtn",' ).
    ri_html->add( '    objectSearch:      "objectSearch",' ).
    ri_html->add( '  }' ).

    ri_html->add( '}' ).
    ri_html->add( 'var gHelper = new StageHelper(gStageParams);' ).

  ENDMETHOD.


  METHOD stage_all.

    FIELD-SYMBOLS <ls_local> LIKE LINE OF ms_files-local.
    FIELD-SYMBOLS <ls_remote> LIKE LINE OF ms_files-remote.
    FIELD-SYMBOLS <ls_status> LIKE LINE OF ms_files-status.

    ro_stage = NEW #( ).

    LOOP AT ms_files-local ASSIGNING <ls_local>.
      READ TABLE ms_files-status ASSIGNING <ls_status>
        WITH TABLE KEY
          path     = <ls_local>-file-path
          filename = <ls_local>-file-filename.
      ASSERT sy-subrc = 0.

      ro_stage->add(
        iv_path     = <ls_local>-file-path
        iv_filename = <ls_local>-file-filename
        is_status   = <ls_status>
        iv_data     = <ls_local>-file-data ).
    ENDLOOP.

    LOOP AT ms_files-remote ASSIGNING <ls_remote>.
      READ TABLE ms_files-status ASSIGNING <ls_status>
        WITH TABLE KEY
          path     = <ls_remote>-path
          filename = <ls_remote>-filename.
      ASSERT sy-subrc = 0.

      IF <ls_status>-lstate = zif_abapgit_definitions=>c_state-deleted
        AND <ls_status>-rstate = zif_abapgit_definitions=>c_state-unchanged.

        ro_stage->rm(
          iv_path     = <ls_remote>-path
          iv_filename = <ls_remote>-filename
          is_status   = <ls_status> ).
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD stage_selected.

    ro_stage = lcl_selected=>get_instance( )->stage_selected(
                     ii_event  = ii_event
                     it_status = ms_files-status
                     it_local  = ms_files-local ).

  ENDMETHOD.


  METHOD zif_abapgit_gui_event_handler~on_event.

    DATA: lo_stage  TYPE REF TO zcl_abapgit_stage.

    CASE ii_event->mv_action.
      WHEN c_action-stage_all.

        lo_stage = stage_all( ).

        rs_handled-page = zcl_abapgit_gui_page_commit=>create(
          ii_repo_online = mi_repo_online
          io_stage       = lo_stage
          iv_sci_result  = mv_sci_result ).

        rs_handled-state = zcl_abapgit_gui=>c_event_state-new_page.

      WHEN c_action-stage_commit.

        lo_stage = stage_selected( ii_event ).

        rs_handled-page = zcl_abapgit_gui_page_commit=>create(
          ii_repo_online = mi_repo_online
          io_stage       = lo_stage
          iv_sci_result  = mv_sci_result ).

        rs_handled-state = zcl_abapgit_gui=>c_event_state-new_page.

      WHEN c_action-stage_filter.

        mv_filter_value = ii_event->form_data( )->get( 'filterValue' ).
        rs_handled-state = zcl_abapgit_gui=>c_event_state-no_more_act.

      WHEN zif_abapgit_definitions=>c_action-go_patch.                         " Go Patch page

        lo_stage = stage_selected( ii_event ).
        rs_handled-page  = get_page_patch( lo_stage ).
        rs_handled-state = zcl_abapgit_gui=>c_event_state-new_page.

      WHEN c_action-stage_refresh.
        mi_repo->refresh( abap_true ).
        init_files( ).
        rs_handled-state = zcl_abapgit_gui=>c_event_state-re_render.
      WHEN zif_abapgit_definitions=>c_action-git_branch_switch.
        zcl_abapgit_services_git=>switch_branch( |{ ii_event->query( )->get( 'KEY' ) }| ).
        mi_repo->refresh( abap_true ).
        init_files( ).
        rs_handled-state = zcl_abapgit_gui=>c_event_state-re_render.
    ENDCASE.

  ENDMETHOD.


  METHOD zif_abapgit_gui_hotkeys~get_hotkey_actions.

    DATA ls_hotkey_action LIKE LINE OF rt_hotkey_actions.

    ls_hotkey_action-ui_component = 'Stage'.
    ls_hotkey_action-description  = |Patch|.
    ls_hotkey_action-action       = 'submitPatch'. " JS function in StageHelper
    ls_hotkey_action-hotkey       = |p|.
    INSERT ls_hotkey_action INTO TABLE rt_hotkey_actions.

    ls_hotkey_action-description  = |Diff|.
    ls_hotkey_action-action       = zif_abapgit_definitions=>c_action-go_repo_diff.
    ls_hotkey_action-hotkey       = |d|.
    INSERT ls_hotkey_action INTO TABLE rt_hotkey_actions.

    ls_hotkey_action-description  = |Refresh|.
    ls_hotkey_action-action       = c_action-stage_refresh.
    ls_hotkey_action-hotkey       = |r|.
    INSERT ls_hotkey_action INTO TABLE rt_hotkey_actions.

    " registered/handled in js
    ls_hotkey_action-description = |Focus filter|.
    ls_hotkey_action-action = `#`.
    ls_hotkey_action-hotkey = |f|.
    INSERT ls_hotkey_action INTO TABLE rt_hotkey_actions.

  ENDMETHOD.


  METHOD zif_abapgit_gui_menu_provider~get_menu.

    ro_toolbar = zcl_abapgit_html_toolbar=>create( 'toolbar-staging' ).

    IF lines( ms_files-local ) > 0 OR lines( ms_files-remote ) > 0.
      ro_toolbar->add(
        iv_txt = 'Refresh'
        iv_act = |{ c_action-stage_refresh }|
        iv_opt = zif_abapgit_html=>c_html_opt-strong
      )->add(
        iv_txt = |Diff|
        iv_act = |{ zif_abapgit_definitions=>c_action-go_repo_diff }?key={ mi_repo->get_key( ) }|
      )->add(
        iv_txt = |Patch|
        iv_typ = zif_abapgit_html=>c_action_type-onclick
        iv_id  = |patchBtn|
      )->add(
        iv_txt = |Back|
        iv_act = zif_abapgit_definitions=>c_action-go_back ).
    ENDIF.

  ENDMETHOD.


  METHOD zif_abapgit_gui_renderable~render.

    register_handlers( ).

    ri_html = NEW zcl_abapgit_html( ).

    ri_html->add( '<div class="repo">' ).
    ri_html->add( zcl_abapgit_gui_chunk_lib=>render_repo_top(
      ii_repo               = mi_repo
      iv_show_commit        = abap_false
      iv_interactive_branch = abap_true ) ).
    ri_html->add( zcl_abapgit_gui_chunk_lib=>render_js_error_banner( ) ).
    ri_html->add( render_main_language_warning( ) ).

    ri_html->add( '<div class="stage-container">' ).
    ri_html->add( render_actions( ) ).
    ri_html->add( render_list( ) ).
    ri_html->add( '</div>' ).

    ri_html->add( '</div>' ).

    gui_services( )->get_html_parts( )->add_part(
      iv_collection = zcl_abapgit_gui_component=>c_html_parts-hidden_forms
      ii_part       = render_deferred_hidden_events( ) ).
    register_deferred_script( render_scripts( ) ).

  ENDMETHOD.
ENDCLASS.
