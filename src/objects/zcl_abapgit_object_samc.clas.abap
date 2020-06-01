CLASS zcl_abapgit_object_samc DEFINITION PUBLIC INHERITING FROM zcl_abapgit_objects_saxx_super FINAL.

  PROTECTED SECTION.
    METHODS:
      get_persistence_class_name REDEFINITION,
      get_data_class_name REDEFINITION,
      get_data_structure_name REDEFINITION.

ENDCLASS.



CLASS ZCL_ABAPGIT_OBJECT_SAMC IMPLEMENTATION.


  METHOD get_data_class_name.

    rv_data_class_name = 'CL_AMC_APPLICATION_OBJ_DATA'.

  ENDMETHOD.


  METHOD get_data_structure_name.

    rv_data_structure_name = 'AMC_APPLICATION_COMPLETE'.

  ENDMETHOD.


  METHOD get_persistence_class_name.

    rv_persistence_class_name = 'CL_AMC_APPLICATION_OBJ_PERS'.

  ENDMETHOD.
ENDCLASS.
