CLASS zcl_abapgit_oo_base DEFINITION
  PUBLIC
  ABSTRACT
  CREATE PROTECTED.

  PUBLIC SECTION.

    INTERFACES zif_abapgit_oo_object_fnc .
    CONSTANTS c_cp_program_type TYPE c LENGTH 1 VALUE 'K'.
    CONSTANTS c_include_program_type TYPE c LENGTH 1 VALUE 'I'.
    CONSTANTS c_ip_program_type TYPE c LENGTH 1 VALUE 'J'.
  PROTECTED SECTION.
    CLASS-METHODS:
      convert_attrib_to_vseoattrib
        IMPORTING iv_clsname           TYPE seoclsname
                  it_attributes        TYPE zif_abapgit_oo_object_fnc=>ty_obj_attribute_tt
        RETURNING VALUE(rt_vseoattrib) TYPE seoo_attributes_r.

  PRIVATE SECTION.
    CONSTANTS c_docu_state_active TYPE dokstate VALUE 'A'. " See include SDOC_CONSTANTS

    DATA mv_skip_test_classes TYPE abap_bool .

ENDCLASS.



CLASS ZCL_ABAPGIT_OO_BASE IMPLEMENTATION.


  METHOD convert_attrib_to_vseoattrib.
    FIELD-SYMBOLS: <ls_attribute>  LIKE LINE OF it_attributes,
                   <ls_vseoattrib> LIKE LINE OF rt_vseoattrib.

    LOOP AT it_attributes ASSIGNING <ls_attribute>.
      INSERT INITIAL LINE INTO TABLE rt_vseoattrib ASSIGNING <ls_vseoattrib>.
      MOVE-CORRESPONDING <ls_attribute> TO <ls_vseoattrib>.
      <ls_vseoattrib>-clsname = iv_clsname.
      <ls_vseoattrib>-state = seoc_state_implemented.
      <ls_vseoattrib>-exposure = <ls_attribute>-exposure.
      UNASSIGN <ls_vseoattrib>.
    ENDLOOP.
    UNASSIGN <ls_attribute>.
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~add_to_activation_list.
    zcl_abapgit_objects_activation=>add_item( is_item ).
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~create.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~create_documentation.
    CALL FUNCTION 'DOCU_UPD'
      EXPORTING
        id            = iv_id
        langu         = iv_language
        object        = iv_object_name
        no_masterlang = iv_no_masterlang
        state         = c_docu_state_active
      TABLES
        line          = it_lines
      EXCEPTIONS
        ret_code      = 1
        OTHERS        = 2.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise_t100( ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~create_sotr.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~delete.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~delete_documentation.
    CALL FUNCTION 'DOCU_DEL'
      EXPORTING
        id       = iv_id
        langu    = iv_language
        object   = iv_object_name
        typ      = 'E'
      EXCEPTIONS
        ret_code = 1
        OTHERS   = 2.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( 'Error from DOCU_DEL' ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~deserialize_source.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~exists.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~generate_locals.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~get_class_properties.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~get_includes.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~get_interface_properties.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~get_skip_test_classes.
    rv_skip = mv_skip_test_classes.
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~insert_text_pool.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~read_attributes.
    SELECT cmpname attbusobj attkeyfld exposure
      FROM seocompodf
      INTO CORRESPONDING FIELDS OF TABLE rt_attributes
      WHERE clsname = iv_object_name
        AND ( attbusobj <> space OR attkeyfld <> space )
        AND version = '1'
      ORDER BY PRIMARY KEY.
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~read_descriptions_class.
    FIELD-SYMBOLS <ls_description> LIKE LINE OF rt_descriptions.

    " Only translations i.e. not the main language
    SELECT * FROM seoclasstx INTO TABLE rt_descriptions
            WHERE clsname   = iv_object_name
              AND langu    <> iv_language
              AND descript <> ''
            ORDER BY PRIMARY KEY.                         "#EC CI_SUBRC

    LOOP AT rt_descriptions ASSIGNING <ls_description>.
      CLEAR <ls_description>-clsname.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~read_descriptions_compo.
    FIELD-SYMBOLS <ls_description> LIKE LINE OF rt_descriptions.

    IF iv_language IS INITIAL.
      " load all languages
      SELECT * FROM seocompotx INTO TABLE rt_descriptions
             WHERE clsname   = iv_object_name
               AND descript <> ''
             ORDER BY PRIMARY KEY.                        "#EC CI_SUBRC
    ELSE.
      " load main language
      SELECT * FROM seocompotx INTO TABLE rt_descriptions
              WHERE clsname   = iv_object_name
                AND langu     = iv_language
                AND descript <> ''
              ORDER BY PRIMARY KEY.                       "#EC CI_SUBRC
    ENDIF.

    LOOP AT rt_descriptions ASSIGNING <ls_description>.
      CLEAR <ls_description>-clsname.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~read_descriptions_subco.
    FIELD-SYMBOLS <ls_description> LIKE LINE OF rt_descriptions.

    IF iv_language IS INITIAL.
      " load all languages
      SELECT * FROM seosubcotx INTO TABLE rt_descriptions
             WHERE clsname   = iv_object_name
               AND descript <> ''
             ORDER BY PRIMARY KEY.                        "#EC CI_SUBRC
    ELSE.
      " load main language
      SELECT * FROM seosubcotx INTO TABLE rt_descriptions
              WHERE clsname   = iv_object_name
                AND langu     = iv_language
                AND descript <> ''
              ORDER BY PRIMARY KEY.                       "#EC CI_SUBRC
    ENDIF.

    LOOP AT rt_descriptions ASSIGNING <ls_description>.
      CLEAR <ls_description>-clsname.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~read_documentation.
    DATA: lv_state TYPE dokstate,
          lt_lines TYPE tlinetab.

    CALL FUNCTION 'DOCU_GET'
      EXPORTING
        id                     = iv_id
        langu                  = iv_language
        object                 = iv_object_name
        version_active_or_last = space " retrieve active version
      IMPORTING
        dokstate               = lv_state
      TABLES
        line                   = lt_lines
      EXCEPTIONS
        no_docu_on_screen      = 1
        no_docu_self_def       = 2
        no_docu_temp           = 3
        ret_code               = 4
        OTHERS                 = 5.
    IF sy-subrc = 0 AND lv_state = c_docu_state_active.
      rt_lines = lt_lines.
    ELSE.
      CLEAR rt_lines.
    ENDIF.
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~read_sotr.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~read_superclass.
    SELECT SINGLE refclsname FROM vseoextend INTO rv_superclass
      WHERE clsname = iv_classname.
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~read_text_pool.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~serialize_abap.
    DATA lo_oo_serializer TYPE REF TO zcl_abapgit_oo_serializer.
    lo_oo_serializer = NEW #( ).
    CASE iv_type.
      WHEN seop_ext_class_locals_def.
        rt_source = lo_oo_serializer->serialize_locals_def( is_class_key ).
      WHEN seop_ext_class_locals_imp.
        rt_source = lo_oo_serializer->serialize_locals_imp( is_class_key ).
      WHEN seop_ext_class_macros.
        rt_source = lo_oo_serializer->serialize_macros( is_class_key ).
      WHEN seop_ext_class_testclasses.
        rt_source = lo_oo_serializer->serialize_testclasses( is_class_key ).
        mv_skip_test_classes = lo_oo_serializer->are_test_classes_skipped( ).
      WHEN OTHERS.
        rt_source = lo_oo_serializer->serialize_abap_clif_source( is_class_key ).
    ENDCASE.
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~syntax_check.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~update_descriptions_class.
    DATA lt_descriptions LIKE it_descriptions.
    DATA ls_description LIKE LINE OF it_descriptions.

    " Make sure we keep main language
    SELECT * FROM seoclasstx INTO TABLE lt_descriptions
      WHERE clsname = is_key-clsname AND langu = iv_language
      ORDER BY PRIMARY KEY.

    LOOP AT it_descriptions INTO ls_description WHERE langu <> iv_language.
      ls_description-clsname = is_key-clsname.
      INSERT ls_description INTO TABLE lt_descriptions.
    ENDLOOP.

    DELETE FROM seoclasstx WHERE clsname = is_key-clsname. "#EC CI_SUBRC
    INSERT seoclasstx FROM TABLE lt_descriptions.         "#EC CI_SUBRC
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~update_descriptions_compo.
    DATA lt_descriptions LIKE it_descriptions.
    DATA lt_components   TYPE seo_components.
    DATA ls_description  LIKE LINE OF it_descriptions.
    DATA lv_lang         TYPE tadir-masterlang.

    FIELD-SYMBOLS <ls_description> LIKE LINE OF it_descriptions.
    FIELD-SYMBOLS <ls_component> TYPE vseocompdf.

    lt_descriptions = it_descriptions.
    LOOP AT lt_descriptions ASSIGNING <ls_description>.
      <ls_description>-clsname = is_key-clsname.
    ENDLOOP.

    " make sure to not damage VSEO* views by deleting texts of all components - an empty text must be kept!!
    SELECT * FROM vseocompdf INTO TABLE lt_components
      WHERE clsname = is_key-clsname
        AND version <> seoc_version_deleted
        AND state = seoc_state_implemented
        AND alias = seox_false ORDER BY clsname cmpname version.

    IF lt_components IS NOT INITIAL.
      SELECT SINGLE masterlang FROM tadir INTO lv_lang
        WHERE pgmid = 'R3TR' AND ( object = 'CLAS' OR object = 'INTF' )
          AND obj_name = is_key-clsname.                "#EC CI_GENBUFF
      IF sy-subrc <> 0.
        lv_lang = sy-langu.
      ENDIF.

      LOOP AT lt_components ASSIGNING <ls_component>.
        READ TABLE lt_descriptions TRANSPORTING NO FIELDS WITH KEY
          clsname = is_key-clsname
          cmpname = <ls_component>-cmpname.
        IF sy-subrc <> 0.
          ls_description-clsname = is_key-clsname.
          ls_description-cmpname = <ls_component>-cmpname.
          ls_description-langu  = lv_lang.
          ls_description-descript = space.
          APPEND ls_description TO lt_descriptions.
        ENDIF.
      ENDLOOP.
    ENDIF.

    DELETE FROM seocompotx WHERE clsname = is_key-clsname. "#EC CI_SUBRC
    INSERT seocompotx FROM TABLE lt_descriptions.         "#EC CI_SUBRC
  ENDMETHOD.


  METHOD zif_abapgit_oo_object_fnc~update_descriptions_subco.
    DATA lt_descriptions  LIKE it_descriptions.
    DATA lt_subcomponents TYPE seo_subcomponents.
    DATA ls_description   LIKE LINE OF it_descriptions.
    DATA lv_lang          TYPE tadir-masterlang.

    FIELD-SYMBOLS <ls_description> LIKE LINE OF it_descriptions.
    FIELD-SYMBOLS <ls_subcomponent> TYPE vseosubcdf.

    lt_descriptions = it_descriptions.
    LOOP AT lt_descriptions ASSIGNING <ls_description>.
      <ls_description>-clsname = is_key-clsname.
    ENDLOOP.

    " make sure to not damage VSEO* views by deleting texts of all subcomponents - an empty text must be kept!!
    SELECT * FROM vseosubcdf INTO TABLE lt_subcomponents
      WHERE clsname = is_key-clsname
        AND version <> seoc_version_deleted ORDER BY clsname cmpname sconame version.

    IF lt_subcomponents IS NOT INITIAL.
      SELECT SINGLE masterlang FROM tadir INTO lv_lang
        WHERE pgmid = 'R3TR' AND ( object = 'CLAS' OR object = 'INTF' )
          AND obj_name = is_key-clsname.                "#EC CI_GENBUFF
      IF sy-subrc <> 0.
        lv_lang = sy-langu.
      ENDIF.

      LOOP AT lt_subcomponents ASSIGNING <ls_subcomponent>.
        READ TABLE lt_descriptions TRANSPORTING NO FIELDS WITH KEY
          clsname = is_key-clsname
          cmpname = <ls_subcomponent>-cmpname
          sconame = <ls_subcomponent>-sconame.
        IF sy-subrc <> 0.
          ls_description-clsname = is_key-clsname.
          ls_description-cmpname = <ls_subcomponent>-cmpname.
          ls_description-sconame = <ls_subcomponent>-sconame.
          ls_description-langu  = lv_lang.
          ls_description-descript = space.
          APPEND ls_description TO lt_descriptions.
        ENDIF.
      ENDLOOP.
    ENDIF.

    DELETE FROM seosubcotx WHERE clsname = is_key-clsname. "#EC CI_SUBRC
    INSERT seosubcotx FROM TABLE lt_descriptions.         "#EC CI_SUBRC
  ENDMETHOD.
ENDCLASS.
