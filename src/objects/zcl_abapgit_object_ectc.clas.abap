CLASS zcl_abapgit_object_ectc DEFINITION
  PUBLIC
  INHERITING FROM zcl_abapgit_object_ecatt_super
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
  PROTECTED SECTION.
    METHODS:
      get_object_type REDEFINITION,
      get_upload REDEFINITION,
      get_download REDEFINITION,
      get_lock_object REDEFINITION.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_abapgit_object_ectc IMPLEMENTATION.


  METHOD get_download.

    ro_download = NEW zcl_abapgit_ecatt_config_downl( ).

  ENDMETHOD.


  METHOD get_lock_object.

    rv_lock_object = 'E_ECATT_TC'.

  ENDMETHOD.


  METHOD get_object_type.

    rv_object_type = cl_apl_ecatt_const=>obj_type_test_config.

  ENDMETHOD.


  METHOD get_upload.

    ro_upload = NEW zcl_abapgit_ecatt_config_upl( ).

  ENDMETHOD.
ENDCLASS.
