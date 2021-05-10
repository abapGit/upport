CLASS ltcl_xml DEFINITION DEFERRED.

CLASS ltcl_xml_concrete DEFINITION FOR TESTING
    FINAL
    INHERITING FROM zcl_abapgit_xml
    FRIENDS ltcl_xml.
ENDCLASS.

CLASS ltcl_xml_concrete IMPLEMENTATION.
ENDCLASS.

CLASS ltcl_xml DEFINITION FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    METHODS setup.

    METHODS:
      space_leading_trailing FOR TESTING
        RAISING zcx_abapgit_exception,
      bad_xml_without_gui_raises_exc FOR TESTING RAISING cx_static_check.

    METHODS:
      parse_xml
        IMPORTING
          iv_xml TYPE csequence
        RAISING
          zcx_abapgit_exception,
      render_xml
        IMPORTING
          iv_name       TYPE string
        RETURNING
          VALUE(rv_xml) TYPE string.

    DATA mo_xml TYPE REF TO ltcl_xml_concrete.

ENDCLASS.


CLASS ltcl_xml IMPLEMENTATION.

  METHOD setup.
    mo_xml = NEW #( ).
  ENDMETHOD.

  METHOD parse_xml.

    DATA lv_xml TYPE string.

    lv_xml = |<?xml version="1.0"?>|
          && |<{ mo_xml->c_abapgit_tag } { mo_xml->c_attr_version }="{ zif_abapgit_version=>gc_xml_version }">|
          && iv_xml
          && |</{ mo_xml->c_abapgit_tag }>|.

    mo_xml->parse( iv_xml = lv_xml ).

  ENDMETHOD.

  METHOD space_leading_trailing.

    DATA: lv_from_xml TYPE string,
          lv_to_xml   TYPE string.


    lv_from_xml = `<FOO> A </FOO>`.

    parse_xml( lv_from_xml ).

    lv_to_xml = render_xml( 'FOO' ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_to_xml
      exp = lv_from_xml ).

  ENDMETHOD.

  METHOD render_xml.

    DATA: li_element       TYPE REF TO if_ixml_element,
          li_ostream       TYPE REF TO if_ixml_ostream,
          li_streamfactory TYPE REF TO if_ixml_stream_factory.

    li_element = mo_xml->mi_xml_doc->find_from_path( |/{ mo_xml->c_abapgit_tag }/{ iv_name }| ).

    li_streamfactory = mo_xml->mi_ixml->create_stream_factory( ).

    li_ostream = li_streamfactory->create_ostream_cstring( rv_xml ).

    li_element->render( ostream = li_ostream ).

  ENDMETHOD.

  METHOD bad_xml_without_gui_raises_exc.
    DATA: lv_xml TYPE string,
          lo_error TYPE REF TO zcx_abapgit_exception,
          lv_text TYPE string.

    IF zcl_abapgit_ui_factory=>get_gui_functions( )->gui_is_available( ) = abap_true.
      RETURN. "Can only test with ADT or in background
    ENDIF.

    lv_xml = |<?xml version="1.0"?>|
          && |<{ mo_xml->c_abapgit_tag } { mo_xml->c_attr_version }="{ zif_abapgit_version=>gc_xml_version }">|
          && |<open_tag>|
          && |</{ mo_xml->c_abapgit_tag }>|.

    TRY.
        mo_xml->parse( iv_xml = lv_xml ).
        cl_abap_unit_assert=>fail( msg = 'Exception not raised' ).

      CATCH zcx_abapgit_exception INTO lo_error.
        lv_text = lo_error->get_text( ).
        cl_abap_unit_assert=>assert_char_cp(
            act              = lv_text
            exp              = '*open_tag*' ).
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
