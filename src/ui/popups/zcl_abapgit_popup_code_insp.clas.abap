CLASS zcl_abapgit_popup_code_insp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES zif_abapgit_gui_render_item .
    INTERFACES zif_abapgit_html_popup .

    CLASS-METHODS create
      RETURNING
        VALUE(ri_popup) TYPE REF TO zif_abapgit_html_popup .
  PROTECTED SECTION.
  PRIVATE SECTION.

    METHODS fetch_list
      RETURNING
        VALUE(rt_list) TYPE zif_abapgit_code_inspector=>ty_variants
      RAISING
        zcx_abapgit_exception.

ENDCLASS.



CLASS zcl_abapgit_popup_code_insp IMPLEMENTATION.


  METHOD create.
    ri_popup = NEW zcl_abapgit_popup_code_insp( ).
  ENDMETHOD.


  METHOD fetch_list.

    rt_list = zcl_abapgit_code_inspector=>get_code_inspector( '$TMP' )->list_global_variants( ).

  ENDMETHOD.


  METHOD zif_abapgit_gui_render_item~render.

    FIELD-SYMBOLS <ls_item> TYPE LINE OF zif_abapgit_code_inspector=>ty_variants.

    ASSIGN iv_item TO <ls_item>.

    ri_html = zcl_abapgit_html=>create( |<b>{ <ls_item>-name }</b> - { <ls_item>-description }| ).

  ENDMETHOD.


  METHOD zif_abapgit_html_popup~create_picklist.

    ro_picklist = NEW #( iv_title = 'Choose Variant'
                         it_list = fetch_list( )
                         ii_item_renderer = me ).

  ENDMETHOD.
ENDCLASS.
