CLASS zcl_abapgit_stage_logic DEFINITION
  PUBLIC
  CREATE PRIVATE.

  PUBLIC SECTION.

    INTERFACES zif_abapgit_stage_logic.

    CLASS-METHODS get_stage_logic
      RETURNING
        VALUE(ri_logic) TYPE REF TO zif_abapgit_stage_logic.

    CLASS-METHODS set_stage_logic
      IMPORTING
        ii_logic TYPE REF TO zif_abapgit_stage_logic.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-DATA gi_stage_logic TYPE REF TO zif_abapgit_stage_logic.

    CLASS-METHODS:
      remove_ignored
        IMPORTING ii_repo  TYPE REF TO zif_abapgit_repo
        CHANGING  cs_files TYPE zif_abapgit_definitions=>ty_stage_files,
      remove_identical
        CHANGING cs_files TYPE zif_abapgit_definitions=>ty_stage_files.

ENDCLASS.



CLASS zcl_abapgit_stage_logic IMPLEMENTATION.


  METHOD get_stage_logic.

    IF gi_stage_logic IS INITIAL.
      gi_stage_logic = NEW zcl_abapgit_stage_logic( ).
    ENDIF.

    ri_logic = gi_stage_logic.

  ENDMETHOD.


  METHOD remove_identical.

    DATA: lv_index  TYPE i,
          ls_remote LIKE LINE OF cs_files-remote.

    FIELD-SYMBOLS: <ls_local> LIKE LINE OF cs_files-local.

    SORT cs_files-remote BY path filename.

    LOOP AT cs_files-local ASSIGNING <ls_local>.
      lv_index = sy-tabix.

      READ TABLE cs_files-remote INTO ls_remote
        WITH KEY path = <ls_local>-file-path filename = <ls_local>-file-filename
        BINARY SEARCH.
      IF sy-subrc = 0.
        DELETE cs_files-remote INDEX sy-tabix.
        IF ls_remote-sha1 = <ls_local>-file-sha1.
          DELETE cs_files-local INDEX lv_index.
        ENDIF.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD remove_ignored.

    DATA: lv_index TYPE i.

    FIELD-SYMBOLS: <ls_remote> LIKE LINE OF cs_files-remote,
                   <ls_local>  LIKE LINE OF cs_files-local.


    LOOP AT cs_files-remote ASSIGNING <ls_remote>.
      lv_index = sy-tabix.

      IF ii_repo->get_dot_abapgit( )->is_ignored(
          iv_path     = <ls_remote>-path
          iv_filename = <ls_remote>-filename ) = abap_true.
        DELETE cs_files-remote INDEX lv_index.
      ELSEIF <ls_remote>-path = zif_abapgit_definitions=>c_root_dir
          AND <ls_remote>-filename = zif_abapgit_definitions=>c_dot_abapgit.
        " Remove .abapgit from remotes - it cannot be removed or ignored
        DELETE cs_files-remote INDEX lv_index.
      ENDIF.

    ENDLOOP.

    LOOP AT cs_files-local ASSIGNING <ls_local>.
      lv_index = sy-tabix.

      IF ii_repo->get_dot_abapgit( )->is_ignored(
          iv_path     = <ls_local>-file-path
          iv_filename = <ls_local>-file-filename ) = abap_true.
        DELETE cs_files-local INDEX lv_index.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD set_stage_logic.
    gi_stage_logic = ii_logic.
  ENDMETHOD.


  METHOD zif_abapgit_stage_logic~get.

    " Getting REMOTE before LOCAL is critical to ensure that DATA config is loaded first
    rs_files-remote = ii_repo_online->get_files_remote( ii_obj_filter ).

    IF ii_obj_filter IS INITIAL.
      rs_files-local  = ii_repo_online->get_files_local( ).
    ELSE.
      rs_files-local  = ii_repo_online->get_files_local_filtered( ii_obj_filter ).
    ENDIF.

    rs_files-status = zcl_abapgit_repo_status=>calculate( ii_repo       = ii_repo_online
                                                          ii_obj_filter = ii_obj_filter ).

    remove_identical( CHANGING cs_files = rs_files ).
    remove_ignored( EXPORTING ii_repo  = ii_repo_online
                    CHANGING  cs_files = rs_files ).

  ENDMETHOD.
ENDCLASS.
