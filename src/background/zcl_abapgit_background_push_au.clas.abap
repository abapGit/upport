CLASS zcl_abapgit_background_push_au DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES zif_abapgit_background .
  PROTECTED SECTION.

    DATA mi_log TYPE REF TO zif_abapgit_log .

    METHODS build_comment
      IMPORTING
        !is_files         TYPE zif_abapgit_definitions=>ty_stage_files
      RETURNING
        VALUE(rv_comment) TYPE string .
    METHODS push_auto
      IMPORTING
        !ii_repo_online TYPE REF TO zif_abapgit_repo_online
      RAISING
        zcx_abapgit_exception .
    METHODS determine_user_details
      IMPORTING
        !iv_changed_by TYPE syuname
      RETURNING
        VALUE(rs_user) TYPE zif_abapgit_git_definitions=>ty_git_user .
    METHODS push_deletions
      IMPORTING
        !ii_repo_online TYPE REF TO zif_abapgit_repo_online
        !is_files       TYPE zif_abapgit_definitions=>ty_stage_files
      RAISING
        zcx_abapgit_exception .
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_abapgit_background_push_au IMPLEMENTATION.


  METHOD build_comment.

    DATA: lt_objects TYPE STANDARD TABLE OF string WITH DEFAULT KEY,
          lv_str     TYPE string.

    FIELD-SYMBOLS: <ls_local> LIKE LINE OF is_files-local.


    LOOP AT is_files-local ASSIGNING <ls_local>.
      lv_str = |{ <ls_local>-item-obj_type } { <ls_local>-item-obj_name }|.
      APPEND lv_str TO lt_objects.
    ENDLOOP.

    SORT lt_objects AS TEXT.
    DELETE ADJACENT DUPLICATES FROM lt_objects.

    IF lines( lt_objects ) = 1.
      rv_comment = |BG: { lv_str }|.
    ELSE.
      rv_comment = 'BG: Multiple objects'.
      LOOP AT lt_objects INTO lv_str.
        CONCATENATE rv_comment cl_abap_char_utilities=>newline lv_str INTO rv_comment.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.


  METHOD determine_user_details.

    DATA li_user_record TYPE REF TO zif_abapgit_user_record.


    li_user_record = zcl_abapgit_env_factory=>get_user_record( ).
    rs_user-name = li_user_record->get_name( iv_changed_by ).
    rs_user-email = li_user_record->get_email( iv_changed_by ).

*   If no email, fall back to localhost/default email
    IF rs_user-email IS INITIAL.
      rs_user-email = |{ iv_changed_by }@localhost|.
    ENDIF.

*   If no full name maintained, just use changed by user name
    IF rs_user-name IS INITIAL.
      rs_user-name  = iv_changed_by.
    ENDIF.

  ENDMETHOD.


  METHOD push_auto.

    TYPES: BEGIN OF ty_changed,
             filename   TYPE string,
             path       TYPE string,
             changed_by TYPE syuname,
           END OF ty_changed.

    DATA: ls_comment    TYPE zif_abapgit_git_definitions=>ty_comment,
          ls_files      TYPE zif_abapgit_definitions=>ty_stage_files,
          lt_changed    TYPE HASHED TABLE OF ty_changed WITH UNIQUE KEY filename path changed_by,
          ls_changed    TYPE ty_changed,
          lt_users      TYPE STANDARD TABLE OF syuname WITH DEFAULT KEY,
          ls_user_files LIKE ls_files,
          lv_changed_by LIKE LINE OF lt_users,
          lo_stage      TYPE REF TO zcl_abapgit_stage.

    FIELD-SYMBOLS:
      <ls_remote> LIKE LINE OF ls_files-remote,
      <ls_local>  LIKE LINE OF ls_files-local.


    ls_files = zcl_abapgit_stage_logic=>get_stage_logic( )->get( ii_repo_online ).

    LOOP AT ls_files-local ASSIGNING <ls_local>.
      lv_changed_by = zcl_abapgit_objects=>changed_by(
        is_item     = <ls_local>-item
        iv_filename = <ls_local>-file-filename ).
      APPEND lv_changed_by TO lt_users.

      CLEAR ls_changed.
      ls_changed-changed_by = lv_changed_by.
      ls_changed-filename   = <ls_local>-file-filename.
      ls_changed-path       = <ls_local>-file-path.
      INSERT ls_changed INTO TABLE lt_changed.
    ENDLOOP.

    SORT lt_users ASCENDING.
    DELETE ADJACENT DUPLICATES FROM lt_users.

    LOOP AT lt_users INTO lv_changed_by.
      CLEAR: ls_comment.

*     Fill user details
      ls_comment-committer = determine_user_details( lv_changed_by ).

      lo_stage = NEW #( ).

      CLEAR ls_user_files.

      LOOP AT ls_files-local ASSIGNING <ls_local>.
        READ TABLE lt_changed WITH KEY
          path = <ls_local>-file-path
          filename = <ls_local>-file-filename
          changed_by = lv_changed_by
          TRANSPORTING NO FIELDS.
        IF sy-subrc = 0.
          mi_log->add_info( |stage: {
            ls_comment-committer-name } {
            <ls_local>-file-path } {
            <ls_local>-file-filename }| ).

          lo_stage->add( iv_path     = <ls_local>-file-path
                         iv_filename = <ls_local>-file-filename
                         iv_data     = <ls_local>-file-data ).

          APPEND <ls_local> TO ls_user_files-local.

          LOOP AT ls_files-remote ASSIGNING <ls_remote>
              USING KEY file
              WHERE filename = <ls_local>-file-filename
              AND path <> <ls_local>-file-path
              AND filename <> 'package.devc.xml'.
            mi_log->add_info( |rm: { <ls_remote>-path } { <ls_remote>-filename }| ).

* rm old file when object has moved
            lo_stage->rm(
              iv_path     = <ls_remote>-path
              iv_filename = <ls_remote>-filename ).
            EXIT. " assumption: only one file
          ENDLOOP.
        ENDIF.
      ENDLOOP.

      ls_comment-comment = build_comment( ls_user_files ).

      ii_repo_online->push( is_comment = ls_comment
                            io_stage   = lo_stage ).
    ENDLOOP.

    IF lines( ls_files-remote ) > 0.
      push_deletions( ii_repo_online  = ii_repo_online
                      is_files        = ls_files ).
    ENDIF.

  ENDMETHOD.


  METHOD push_deletions.

    DATA: lo_stage   TYPE REF TO zcl_abapgit_stage,
          ls_comment TYPE zif_abapgit_git_definitions=>ty_comment.

    FIELD-SYMBOLS: <ls_remote> LIKE LINE OF is_files-remote.

    ASSERT lines( is_files-remote ) > 0.

    lo_stage = NEW #( ).

    ls_comment-comment = 'BG: Deletion'.

    LOOP AT is_files-remote ASSIGNING <ls_remote>.

      mi_log->add_info( |removed: { <ls_remote>-path } { <ls_remote>-filename }| ).

      lo_stage->rm( iv_path     = <ls_remote>-path
                    iv_filename = <ls_remote>-filename ).

      CONCATENATE ls_comment-comment cl_abap_char_utilities=>newline <ls_remote>-filename
        INTO ls_comment-comment.

    ENDLOOP.

    ls_comment-committer-name  = 'Deletion'.
    ls_comment-committer-email = 'deletion@localhost'.

    ii_repo_online->push( is_comment = ls_comment
                          io_stage   = lo_stage ).

  ENDMETHOD.


  METHOD zif_abapgit_background~get_description.

    rv_description = 'Automatic push, auto author'.

  ENDMETHOD.


  METHOD zif_abapgit_background~get_settings.

    RETURN.

  ENDMETHOD.


  METHOD zif_abapgit_background~run.

    DATA: ls_files TYPE zif_abapgit_definitions=>ty_stage_files.

    mi_log = ii_log.
    ls_files = zcl_abapgit_stage_logic=>get_stage_logic( )->get( ii_repo_online ).

    IF lines( ls_files-local ) = 0 AND lines( ls_files-remote ) = 0.
      ii_log->add_info( 'Nothing to stage' ).
      RETURN.
    ENDIF.

    push_auto( ii_repo_online ).

  ENDMETHOD.
ENDCLASS.
