Sitetree Page: add form
=======================

*/forms/preside-objects/page/add.xml*

This form is used as the base "add page" form for Sitetree pages. See also :doc:`sitetreepageeditform`.

.. note::

	When an add page form is rendered, it gets mixed in with any forms that are defined for the
	*page type* that is being added.

	See :doc:`/devguides/formlayouts` for a guide on form layouts and mixing forms.

	See :doc:`/devguides/pagetypes` for a guide to page types.

.. code-block:: xml

    <?xml version="1.0" encoding="UTF-8"?>

    <form>
        <tab id="main" title="preside-objects.page:editform.basictab.title" description="preside-objects.page:editform.basictab.description">
            <fieldset id="main">
                <field sortorder="10" binding="page.title" />
                <field sortorder="20" binding="page.main_image" />
                <field sortorder="30" binding="page.slug" control="autoslug" required="true" basedOn="title" />
                <field sortorder="40" binding="page.layout" />
                <field sortorder="50" binding="page.teaser" />
                <field sortorder="60" binding="page.main_content" />
                <field sortorder="70" binding="page.active" />
            </fieldset>
        </tab>

        <tab id="meta" title="preside-objects.page:editform.metadatatab.title" description="preside-objects.page:editform.metadatatab.description">
            <fieldset id="meta">
                <field sortorder="10" binding="page.browser_title" />
                <field sortorder="20" binding="page.author" />
                <field sortorder="30" binding="page.description" />
                <field sortorder="40" binding="page.keywords" />
            </fieldset>
        </tab>

        <tab id="dates" title="preside-objects.page:editform.dateControlTab.title" description="preside-objects.page:editform.dateControlTab.description">
            <fieldset id="dates">
                <field sortorder="10" binding="page.embargo_date" control="datepicker" />
                <field sortorder="20" binding="page.expiry_date"  control="datepicker" />
            </fieldset>
        </tab>

        <tab id="navigation" title="preside-objects.page:editform.navigationtab.title" description="preside-objects.page:editform.navigationtab.description">
            <fieldset id="navigation">
                <field sortorder="10" binding="page.navigation_title" control="textinput" />
                <field sortorder="20" binding="page.exclude_from_navigation" />
            </fieldset>
        </tab>
    </form>

