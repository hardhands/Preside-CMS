User group: add form
====================

*/forms/preside-objects/security_group/admin.edit.xml*

This form is used for the "edit user group" form in the user admin section of the administrator.

.. code-block:: xml

    <?xml version="1.0" encoding="UTF-8"?>

    <form>
        <tab id="basic">
            <fieldset id="basic">
                <field binding="security_group.label" />
                <field binding="security_group.description" />
                <field binding="security_group.roles"  />
            </fieldset>
        </tab>
    </form>

