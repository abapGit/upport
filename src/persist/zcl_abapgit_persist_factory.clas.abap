CLASS zcl_abapgit_persist_factory DEFINITION
  PUBLIC
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_abapgit_persist_injector .

  PUBLIC SECTION.

    CLASS-METHODS get_repo
      RETURNING
        VALUE(ri_repo) TYPE REF TO zif_abapgit_persist_repo .
    CLASS-METHODS get_settings
      RETURNING
        VALUE(ri_settings) TYPE REF TO zif_abapgit_persist_settings .
  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-DATA gi_repo TYPE REF TO zif_abapgit_persist_repo .
    CLASS-DATA gi_settings TYPE REF TO zif_abapgit_persist_settings .
ENDCLASS.



CLASS ZCL_ABAPGIT_PERSIST_FACTORY IMPLEMENTATION.


  METHOD get_repo.

    IF gi_repo IS INITIAL.
      gi_repo = NEW zcl_abapgit_persistence_repo( ).
    ENDIF.

    ri_repo = gi_repo.

  ENDMETHOD.


  METHOD get_settings.

    IF gi_settings IS INITIAL.
      gi_settings = NEW zcl_abapgit_persist_settings( ).
    ENDIF.

    ri_settings = gi_settings.

  ENDMETHOD.
ENDCLASS.
