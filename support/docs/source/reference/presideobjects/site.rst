Site
====

Overview
--------

The Site object represents a site / microsite that is managed by the CMS.
Each site will have its own tree of :doc:`/reference/presideobjects/page` records.

**Object name:**
    site

**Table name:**
    psys_site

**Path:**
    /preside-objects/core/site.cfc

Properties
----------

.. code-block:: java

    property name="name"   type="string" maxlength="200" required="true"  uniqueindexes="sitename";
    property name="domain" type="string" maxlength="255" required="false" uniqueindexes="sitepath|1";
    property name="path"   type="string" maxlength="255" required="false" uniqueindexes="sitepath|2";