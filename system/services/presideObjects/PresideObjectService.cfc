/**
 * The Preside Object Service is the main entry point API for interacting with **Preside Data Objects**. It provides CRUD operations for individual objects as well as many other useful utilities.
 * \n
 * For a full developer guide on using Preside Objects and this service, see :doc:`/devguides/presideobjects`.
 */

component output=false singleton=true autodoc=true displayName="Preside Object Service" {

// CONSTRUCTOR
	/**
	 * @objectDirectories.inject      presidecms:directories:preside-objects
	 * @objectReader.inject           PresideObjectReader
	 * @sqlSchemaSynchronizer.inject  SqlSchemaSynchronizer
	 * @adapterFactory.inject         AdapterFactory
	 * @sqlRunner.inject              SqlRunner
	 * @relationshipGuidance.inject   RelationshipGuidance
	 * @presideObjectDecorator.inject PresideObjectDecorator
	 * @objectCache.inject            cachebox:SystemCache
	 * @defaultQueryCache.inject      cachebox:DefaultQueryCache
	 * @coldboxController.inject      coldbox
	 */
	public any function init(
		  required array   objectDirectories
		, required any     objectReader
		, required any     sqlSchemaSynchronizer
		, required any     adapterFactory
		, required any     sqlRunner
		, required any     relationshipGuidance
		, required any     presideObjectDecorator
		, required any     objectCache
		, required any     defaultQueryCache
		, required any     coldboxController
		,          boolean reloadDb = true
	) output=false {
		_setObjectDirectories( arguments.objectDirectories );
		_setObjectReader( arguments.objectReader );
		_setSqlSchemaSynchronizer( arguments.sqlSchemaSynchronizer );
		_setAdapterFactory( arguments.adapterFactory );
		_setSqlRunner( arguments.sqlRunner );
		_setRelationshipGuidance( arguments.relationshipGuidance );
		_setPresideObjectDecorator( arguments.presideObjectDecorator );
		_setObjectCache( arguments.objectCache );
		_setDefaultQueryCache( arguments.defaultQueryCache );
		_setVersioningService( new VersioningService( this, arguments.coldboxController ) );
		_setCacheMaps( {} );
		_setColdboxController( arguments.coldboxController );

		_loadObjects();

		if ( arguments.reloadDb ) {
			dbSync();
		}

		return this;
	}

// PUBLIC API METHODS
	/**
	 * Returns an 'auto service' object instance of the given Preside Object.
	 * \n
	 * See :ref:`preside-objects-auto-service-objects` for a full guide.
	 * \n
	 * ${arguments}
	 * \n
	 * Example
	 * .......
	 *
	 * .. code-block:: java
	 * \n
	 *
	 * \teventObject = presideObjectService.getObject( "event" );
	 * \n
	 * \teventId     = eventObject.insertData( data={ title="Christmas", startDate="2014-12-25", endDate="2015-01-06" } );
	 * \tevent       = eventObject.selectData( id=eventId )
	 *
	 * @objectName.hint The name of the object to get
	 */
	public any function getObject( required string objectName ) autodoc=true output=false {
		var obj = _getObject( arguments.objectName );

		if ( not StructKeyExists( obj, "decoratedInstance" ) ) {
			obj.decoratedInstance = _getPresideObjectDecorator().decorate(
				  objectName           = arguments.objectName
				, dsn                  = obj.meta.dsn
				, tableName            = obj.meta.tableName
				, objectInstance       = obj.instance
				, presideObjectService = this
			);
		}

		return obj.decoratedInstance;
	}

	/**
	 * Selects database records for the given object based on a variety of input parameters
	 * \n
	 * ${arguments}
	 * \n
	 * Examples
	 * ........
	 * \n
	 * .. code-block:: java
	 * \n
	 * \t// select a record by ID
	 * \tevent = presideObjectService.selectData( objectName="event", id=rc.id );
	 * \n
	 * \t// select records using a simple filter.
	 * \t// notice the 'category.label as categoryName' field - this will
	 * \t// be automatically selected from the related 'category' object
	 * \tevents = presideObjectService.selectData(
	 * \t      objectName   = "event"
	 * \t    , filter       = { category = rc.category }
	 * \t    , selectFields = [ "event.name", "category.label as categoryName", "event.category" ]
	 * \t    , orderby      = "event.name"
	 * \t);
	 * \n
	 * \t// select records with a plain SQL filter with added SQL params
	 * \tevents = presideObjectService.selectData(
	 * \t      objectName   = "event"
	 * \t    , filter       = "category.label like :category.label"
	 * \t    , filterParams = { "category.label" = "%#rc.search#%" }
	 * \t);
	 *
	 * @objectName.hint         Name of the object from which to select data
	 * @id.hint                 ID of a record to select
	 * @selectFields.hint       Array of field names to select. Can include relationships, e.g. ['tags.label as tag']
	 * @filter.hint             Filter the records returned, see :ref:`preside-objects-filtering-data` in :doc:`/devguides/presideobjects`
	 * @filterParams.hint       Filter params for plain SQL filter, see :ref:`preside-objects-filtering-data` in :doc:`/devguides/presideobjects`
	 * @orderBy.hint            Plain SQL order by string
	 * @groupBy.hint            Plain SQL group by string
	 * @maxRows.hint            Maximum number of rows to select
	 * @startRow.hint           Offset the recordset when using maxRows
	 * @useCache.hint           Whether or not to automatically cache the result internally
	 * @fromVersionTable.hint   Whether or not to select the data from the version history table for the object
	 * @maxVersion.hint         Can be used to set a maximum version number when selecting from the version table
	 * @specificVersion.hint    Can be used to select a specific version when selecting from the version table
	 * @forceJoins.hint         Can be set to "inner" / "left" to force *all* joins in the query to a particular join type
	 * @selectFields.docdefault []
	 * @filter.docdefault       {}
	 * @filterParams.docdefault {}
	 */
	public query function selectData(
		  required string  objectName
		,          string  id               = ""
		,          array   selectFields     = []
		,          any     filter           = {}
		,          struct  filterParams     = {}
		,          string  orderBy          = ""
		,          string  groupBy          = ""
		,          numeric maxRows          = 0
		,          numeric startRow         = 1
		,          boolean useCache         = true
		,          boolean fromVersionTable = false
		,          string  maxVersion       = "HEAD"
		,          numeric specificVersion  = 0
		,          string  forceJoins       = ""

	) output=false autodoc=true {
		var result     = "";
		var queryCache = "";
		var cachekey   = "";

		if ( arguments.useCache ) {
			queryCache = _getDefaultQueryCache();
			cachekey   = arguments.objectName & "_" & Hash( LCase( SerializeJson( arguments ) ) );

			if ( objectIsUsingSiteTenancy( arguments.objectName ) ) {
				cacheKey &= "_" & _getActiveSiteId();
			}

			result     = queryCache.get( cacheKey );

			if ( not IsNull( result ) ) {
				return result;
			}
		}

		var sql                  = "";
		var obj                  = _getObject( arguments.objectName ).meta;
		var adapter              = _getAdapter( obj.dsn );
		var compiledSelectFields = _parseSelectFields( arguments.objectName, Duplicate( arguments.selectFields ) );
		var joinTargets          = _extractForeignObjectsFromArguments( objectName=arguments.objectName, selectFields=compiledSelectFields, filter=arguments.filter, orderBy=arguments.orderBy );
		var joins                = [];
		var i                    = "";
		var preparedFilter       = _prepareFilter(
			  objectName        = arguments.objectName
			, id                = arguments.id
			, filter            = arguments.filter
			, filterParams      = arguments.filterParams
			, adapter           = adapter
			, columnDefinitions = obj.properties
		);

		if ( not ArrayLen( compiledSelectFields ) ) {
			compiledSelectFields = _dbFieldListToSelectFieldsArray( obj.dbFieldList, arguments.objectName, adapter );
		}

		if ( ArrayLen( joinTargets ) ) {
			var joinsCache    = _getObjectCache();
			var joinsCacheKey = "SQL Joins for #arguments.objectName# with join targets: #ArrayToList( joinTargets )#"

			joins = joinsCache.get( joinsCacheKey );

			if ( IsNull( joins ) ) {
				joins = _getRelationshipGuidance().calculateJoins( objectName = arguments.objectName, joinTargets = joinTargets, forceJoins = arguments.forceJoins );

				joinsCache.set( joinsCacheKey, joins );
			}
		}

		if ( arguments.fromVersionTable && objectIsVersioned( arguments.objectName ) ) {
			result = _selectFromVersionTables(
				  objectName        = arguments.objectName
				, originalTableName = obj.tableName
				, joins             = joins
				, selectFields      = arguments.selectFields
				, maxVersion        = arguments.maxVersion
				, specificVersion   = arguments.specificVersion
				, filter            = preparedFilter.filter
				, params            = preparedFilter.params
				, orderBy           = arguments.orderBy
				, groupBy           = arguments.groupBy
				, maxRows           = arguments.maxRows
				, startRow          = arguments.startRow
			);
		} else {
			sql = adapter.getSelectSql(
				  tableName     = obj.tableName
				, tableAlias    = arguments.objectName
				, selectColumns = compiledSelectFields
				, filter        = preparedFilter.filter
				, joins         = _convertObjectJoinsToTableJoins( joins )
				, orderBy       = arguments.orderBy
				, groupBy       = arguments.groupBy
				, maxRows       = arguments.maxRows
				, startRow      = arguments.startRow
			);
			result = _runSql( sql=sql, dsn=obj.dsn, params=preparedFilter.params );
		}


		if ( arguments.useCache ) {
			queryCache.set( cacheKey, result );
			_recordCacheSoThatWeCanClearThemWhenDataChanges(
				  objectName   = arguments.objectName
				, cacheKey     = cacheKey
				, filter       = preparedFilter.filter
				, filterParams = preparedFilter.filterParams
				, joinTargets  = joinTargets
			);
		}

		return result;
	}

	/**
	 * Inserts a record into the database, returning the ID of the newly created record
	 * \n
	 * ${arguments}
	 * \n
	 * Example:
	 * \n
	 * .. code-block:: java
	 * \n
	 * \tnewId = presideObjectService.insertData(
	 * \t      objectName = "event"
	 * \t    , data       = { name="Summer BBQ", startdate="2015-08-23", enddate="2015-08-23" }
	 * \t);
	 *
	 * @objectName.hint              Name of the object in which to to insert a record
	 * @data.hint                    Structure of data who's keys map to the properties that are defined on the object
	 * @insertManyToManyRecords.hint Whether or not to insert multiple relationship records for properties that have a many-to-many relationship
	 * @useVersioning.hint           Whether or not to use the versioning system with the insert. If the object is setup to use versioning (default), this will default to true.
	 * @versionNumber.hint           If using versioning, specify a version number to save against (if none specified, one will be created automatically)
	 * @useVersioning.docdefault     automatic
	 */
	public any function insertData(
		  required string  objectName
		, required struct  data
		,          boolean insertManyToManyRecords = false
		,          boolean useVersioning           = objectIsVersioned( arguments.objectName )
		,          numeric versionNumber           = 0

	) output=false autodoc=true {
		var obj                = _getObject( arguments.objectName ).meta;
		var adapter            = _getAdapter( obj.dsn );
		var sql                = "";
		var key                = "";
		var params             = "";
		var result             = "";
		var newId              = "";
		var rightNow           = DateFormat( Now(), "yyyy-mm-dd" ) & " " & TimeFormat( Now(), "HH:mm:ss" );
		var cleanedData        = _addDefaultValuesToDataSet( arguments.objectName, arguments.data );
		var manyToManyData     = {};
		var requiresVersioning = arguments.useVersioning && objectIsVersioned( arguments.objectName );

		for( key in cleanedData ){
			if ( arguments.insertManyToManyRecords and getObjectPropertyAttribute( objectName, key, "relationship", "none" ) eq "many-to-many" ) {
				manyToManyData[ key ] = cleanedData[ key ];
			}
			if ( not ListFindNoCase( obj.dbFieldList, key ) ) {
				StructDelete( cleanedData, key );
			}
		}

		if ( StructKeyExists( obj.properties, "datecreated" ) and not StructKeyExists( cleanedData, "datecreated" ) ) {
			cleanedData.datecreated = rightNow;
		}
		if ( StructKeyExists( obj.properties, "datemodified" ) and not StructKeyExists( cleanedData, "datemodified" ) ) {
			cleanedData.datemodified = rightNow;
		}
		if ( StructKeyExists( obj.properties, "id" ) and ( not StructKeyExists( cleanedData, "id" ) or not Len( Trim( cleanedData.id ) ) ) ) {
			param name="obj.properties.id.generator" default="UUID";
			newId = _generateNewIdWhenNecessary( generator=obj.properties.id.generator );
			if ( Len( Trim( newId ) ) ) {
				cleanedData.id = newId;
			}
		}

		if ( objectIsUsingSiteTenancy( arguments.objectName ) && !Len( Trim( cleanedData.site ?: "" ) ) ) {
			cleanedData.site = _getActiveSiteId();
		}

		transaction {
			if ( requiresVersioning ) {
				_getVersioningService().saveVersionForInsert(
					  objectName     = arguments.objectName
					, data           = cleanedData
					, manyToManyData = manyToManyData
					, versionNumber  = arguments.versionNumber ? arguments.versionNumber : getNextVersionNumber()
				);
			}

			sql    = adapter.getInsertSql( tableName = obj.tableName, insertColumns = StructKeyArray( cleanedData ) );
			params = _convertDataToQueryParams(
				  objectName        = arguments.objectName
				, columnDefinitions = obj.properties
				, data              = cleanedData
				, dbAdapter         = adapter
			);

			result = _runSql( sql=sql[1], dsn=obj.dsn, params=params, returnType="info" );

			newId = Len( Trim( newId ) ) ? newId : ( result.generatedKey ?: "" );
			if ( Len( Trim( newId ) ) ) {
				for( key in manyToManyData ){
					syncManyToManyData(
						  sourceObject   = arguments.objectName
						, sourceProperty = key
						, sourceId       = newId
						, targetIdList   = manyToManyData[ key ]
					);
				}
			}
		}

		_clearRelatedCaches(
			  objectName              = arguments.objectName
			, filter                  = ""
			, filterParams            = {}
			, clearSingleRecordCaches = false
		);

		return newId;
	}

	/**
	 * Updates records in the database with a new set of data. Returns the number of records affected by the operation.
	 * \n
	 * ${arguments}
	 * \n
	 * Examples
	 * ........
	 * \n
	 * .. code-block:: java
	 * \n
	 * \t// update a single record
	 * \tupdated = presideObjectService.updateData(
	 * \t      objectName = "event"
	 * \t    , id         = eventId
	 * \t    , data       = { enddate = "2015-01-31" }
	 * \t);
	 * \n
	 * \t// update multiple records
	 * \tupdated = presideObjectService.updateData(
	 * \t      objectName     = "event"
	 * \t    , data           = { cancelled = true }
	 * \t    , filter         = { category = rc.category }
	 * \t);
	 * \n
	 * \t// update all records
	 * \tupdated = presideObjectService.updateData(
	 * \t      objectName     = "event"
	 * \t    , data           = { cancelled = true }
	 * \t    , forceUpdateAll = true
	 * \t);
	 *
	 *
	 * @objectName.hint              Name of the object who's records you want to update
	 * @data.hint                    Structure of data containing new values. Keys should map to properties on the object.
	 * @id.hint                      ID of a single record to update
	 * @filter.hint                  Filter for which records are updated, see :ref:`preside-objects-filtering-data` in :doc:`/devguides/presideobjects`
	 * @filterParams.hint            Filter params for plain SQL filter, see :ref:`preside-objects-filtering-data` in :doc:`/devguides/presideobjects`
	 * @forceUpdateAll.hint          If no ID and no filters are supplied, this must be set to **true** in order for the update to process
	 * @updateManyToManyRecords.hint Whether or not to update multiple relationship records for properties that have a many-to-many relationship
	 * @useVersioning.hint           Whether or not to use the versioning system with the update. If the object is setup to use versioning (default), this will default to true.
	 * @versionNumber.hint           If using versioning, specify a version number to save against (if none specified, one will be created automatically)
	 * @useVersioning.docdefault     auto
	 */
	public numeric function updateData(
		  required string  objectName
		, required struct  data
		,          string  id                      = ""
		,          any     filter                  = {}
		,          struct  filterParams            = {}
		,          boolean forceUpdateAll          = false
		,          boolean updateManyToManyRecords = false
		,          boolean useVersioning           = objectIsVersioned( arguments.objectName )
		,          numeric versionNumber           = 0
	) output=false autodoc=true {
		var obj                = _getObject( arguments.objectName ).meta;
		var adapter            = _getAdapter( obj.dsn );
		var sql                = "";
		var result             = "";
		var joinTargets        = "";
		var joins              = [];
		var cleanedData        = Duplicate( arguments.data );
		var manyToManyData     = {}
		var key                = "";
		var requiresVersioning = arguments.useVersioning && objectIsVersioned( arguments.objectName );
		var preparedFilter     = "";

		for( key in cleanedData ){
			if ( arguments.updateManyToManyRecords and getObjectPropertyAttribute( objectName, key, "relationship", "none" ) eq "many-to-many" ) {
				manyToManyData[ key ] = cleanedData[ key ];
			}
			if ( not ListFindNoCase( obj.dbFieldList, key ) ) {
				StructDelete( cleanedData, key );
			}
		}

		if ( not Len( Trim( arguments.id ) ) and _isEmptyFilter( arguments.filter ) and not arguments.forceUpdateAll ) {
			throw(
				  type    = "PresideObjects.updateAllProtection"
				, message = "A call to update records in [#arguments.objectName#] was made without any filter which would lead to all records being updated"
				, detail  = "If you wish to update all records, you must set the [forceUpdateAll] argument of the [updateData] method to true"
			);
		}

		if ( StructKeyExists( obj.properties, "datemodified" ) and not StructKeyExists( cleanedData, "datemodified" ) ) {
			cleanedData.datemodified = DateFormat( Now(), "yyyy-mm-dd" ) & " " & TimeFormat( Now(), "HH:mm:ss" );
		}

		joinTargets = _extractForeignObjectsFromArguments( objectName=arguments.objectName, filter=arguments.filter, data=cleanedData );
		if ( ArrayLen( joinTargets ) ) {
			joins = _getRelationshipGuidance().calculateJoins( objectName = arguments.objectName, joinTargets = joinTargets );
			joins = _convertObjectJoinsToTableJoins( joins );
		}

		preparedFilter = _prepareFilter(
			  objectName        = arguments.objectName
			, id                = arguments.id
			, filter            = arguments.filter
			, filterParams      = arguments.filterParams
			, adapter           = adapter
			, columnDefinitions = obj.properties
		);

		transaction {
			if ( requiresVersioning ) {
				_getVersioningService().saveVersionForUpdate(
					  objectName     = arguments.objectName
					, id             = arguments.id
					, filter         = preparedFilter.filter
					, filterParams   = preparedFilter.filterParams
					, data           = cleanedData
					, manyToManyData = manyToManyData
					, versionNumber  = arguments.versionNumber ? arguments.versionNumber : getNextVersionNumber()
				);
			}

			preparedFilter.params = _arrayMerge( preparedFilter.params, _convertDataToQueryParams(
				  objectName        = arguments.objectName
				, columnDefinitions = obj.properties
				, data              = cleanedData
				, dbAdapter         = adapter
				, preFix            = "set__"
			) );

			sql = adapter.getUpdateSql(
				  tableName     = obj.tableName
				, tableAlias    = arguments.objectName
				, updateColumns = StructKeyArray( cleanedData )
				, filter        = preparedFilter.filter
				, joins         = joins
			);

			result = _runSql( sql=sql, dsn=obj.dsn, params=preparedFilter.params, returnType="info" );

			if ( StructCount( manyToManyData ) ) {
				var updatedRecords = [];

				if ( Len( Trim( arguments.id ) ) ) {
					updatedRecords = [ arguments.id ];
				} else {
					updatedRecords = selectData(
						  objectName   = arguments.objectName
						, selectFields = [ "id" ]
						, filter       = preparedFilter.filter
						, filterParams = preparedFilter.filterParams
					);
					updatedRecords = ListToArray( updatedRecords.id );
				}

				for( key in manyToManyData ){
					for( var updatedId in updatedRecords ) {
						syncManyToManyData(
							  sourceObject   = arguments.objectName
							, sourceProperty = key
							, sourceId       = updatedId
							, targetIdList   = manyToManyData[ key ]
						);
					}
				}
			}
		}

		_clearRelatedCaches(
			  objectName   = arguments.objectName
			, filter       = preparedFilter.filter
			, filterParams = preparedFilter.filterParams
		);

		return Val( result.recordCount ?: 0 );
	}

	/**
	 * Deletes records from the database. Returns the number of records deleted.
	 * \n
	 * ${arguments}
	 * \n
	 * Examples
	 * ........
	 * \n
	 * .. code-block:: java
	 * \n
	 * \t// delete a single record
	 * \tdeleted = presideObjectService.deleteData(
	 * \t      objectName = "event"
	 * \t    , id         = rc.id
	 * \t);
	 * \n
	 * \t// delete multiple records using a filter
	 * \t// (note we are filtering on a column in a related object, "category")
	 * \tdeleted = presideObjectService.deleteData(
	 * \t      objectName   = "event"
	 * \t    , filter       = "category.label != :category.label"
	 * \t    , filterParams = { "category.label" = "BBQs" }
	 * \t);
	 * \n
	 * \t// delete all records
	 * \t// (note we are filtering on a column in a related object, "category")
	 * \tdeleted = presideObjectService.deleteData(
	 * \t      objectName     = "event"
	 * \t    , forceDeleteAll = true
	 * \t);
	 *
	 * @objectName.hint     Name of the object from who's database table records are to be deleted
	 * @id.hint             ID of a record to delete
	 * @filter.hint         Filter for records to delete, see :ref:`preside-objects-filtering-data` in :doc:`/devguides/presideobjects`
	 * @filterParams.hint   Filter params for plain SQL filter, see :ref:`preside-objects-filtering-data` in :doc:`/devguides/presideobjects`
	 * @forceDeleteAll.hint If no id or filter supplied, this must be set to **true** in order for the delete to process
	 */
	public numeric function deleteData(
		  required string  objectName
		,          string  id             = ""
		,          any     filter         = {}
		,          struct  filterParams   = {}
		,          boolean forceDeleteAll = false
	) output=false autodoc=true {
		var obj            = _getObject( arguments.objectName ).meta;
		var adapter        = _getAdapter( obj.dsn );
		var sql            = "";
		var result         = "";
		var preparedFilter = "";

		if ( !Len( Trim( arguments.id ) ) && _isEmptyFilter( arguments.filter ) && !arguments.forceDeleteAll ) {
			throw(
				  type    = "PresideObjects.deleteAllProtection"
				, message = "A call to delete records in [#arguments.objectName#] was made without any filter which would lead to all records being deleted"
				, detail  = "If you wish to delete all records, you must set the [forceDeleteAll] argument of the [deleteData] method to true"
			);
		}

		preparedFilter = _prepareFilter(
			  objectName        = arguments.objectName
			, id                = arguments.id
			, filter            = arguments.filter
			, filterParams      = arguments.filterParams
			, adapter           = adapter
			, columnDefinitions = obj.properties
		);

		sql = adapter.getDeleteSql(
			  tableName  = obj.tableName
			, tableAlias = arguments.objectName
			, filter     = preparedFilter.filter
		);

		result = _runSql( sql=sql, dsn=obj.dsn, params=preparedFilter.params, returnType="info" );

		_clearRelatedCaches(
			  objectName   = arguments.objectName
			, filter       = preparedFilter.filter
			, filterParams = preparedFilter.filterParams
		);

		return Val( result.recordCount ?: 0 );
	}

	/**
	 * Returns true if records exist that match the supplied fillter, false otherwise.
	 * \n
	 * .. note::
	 * \n
	 * \tIn addition to the named arguments here, you can also supply any valid arguments
	 * \tthat can be supplied to the :ref:`presideobjectservice-selectdata` method
	 * \n
	 * ${arguments}
	 * \n
	 * Example
	 * .......
	 * \n
	 * .. code-block:: java
	 * \n
	 * \teventsExist = presideObjectService.dataExists(
	 * \t      objectName = "event"
	 * \t    , filter     = { category = rc.category }
	 * \t);
	 *
	 * @objectName.hint         Name of the object in which the records may or may not exist
	 * @filter.hint             Filter the records queried, see :ref:`preside-objects-filtering-data` in :doc:`/devguides/presideobjects`
	 * @filterParams.hint       Filter params for plain SQL filter, see :ref:`preside-objects-filtering-data` in :doc:`/devguides/presideobjects`
	 * @fromVersionTable.hint   Whether or not to query against the version history table
	 * @maxVersion.hint         If querying against the version history table, maximum version to select
	 * @specificVersion.hint    If querying against the version history table, specific version to select
	 */
	public boolean function dataExists(
		  required string  objectName
		,          any     filter       = {}
		,          struct  filterParams = {}
	) output=false autodoc=true {
		var args = arguments;
		args.useCache     = false;
		args.selectFields = [ "1" ];

		return selectData( argumentCollection=args ).recordCount;
	}

	/**
	 * Selects records from many-to-many relationships
	 * \n
	 * .. note::
	 * \n
	 * \tYou can pass additional arguments to those specified below and they will all be passed to the :ref:`presideobjectservice-selectdata` method
	 * \n
	 * ${arguments}
	 * \n
	 * Example
	 * .......
	 * \n
	 * .. code-block:: java
	 * \n
	 * \ttags = presideObjectService.selectManyToManyData(
	 * \t      objectName   = "event"
	 * \t    , propertyName = "tags"
	 * \t    , orderby      = "tags.label"
	 * \t);
	 *
	 * @objectName.hint   Name of the object that has the many-to-many property defined
	 * @propertyName.hint Name of the many-to-many property
	 * @selectFields.hint Array of fields to select
	 * @orderBy.hint      Plain SQL order by statement
	 */
	public query function selectManyToManyData(
		  required string  objectName
		, required string  propertyName
		,          array   selectFields = []
		,          string  orderBy      = ""
	) output=false autodoc=true {
		if ( !isManyToManyProperty( arguments.objectName, arguments.propertyName ) ) {
			throw(
				  type    = "PresideObjectService.notManyToMany"
				, message = "The property [#arguments.propertyName#] of object [#arguments.objectName#] is not a many-to-many field"
			);
		}

		var relatedTo      = getObjectPropertyAttribute( arguments.objectName, arguments.propertyName, "relatedTo", "" );
		var obj            = _getObject( relatedTo );
		var selectDataArgs = Duplicate( arguments );

		StructDelete( selectDataArgs, "propertyName" );
		selectDataArgs.forceJoins = "inner"; // many-to-many joins are not required so "left" by default. Here we absolutely want inner joins.

		if ( not ArrayLen( selectDataArgs.selectFields ) ) {
			var dbAdapter = getDbAdapterForObject( relatedTo );
			selectDataArgs.selectFields = ListToArray( obj.meta.dbFieldList );
			for( var i=1; i <= selectDataArgs.selectFields.len(); i++ ) {
				selectDataArgs.selectFields[i] = arguments.propertyName & "." & selectDataArgs.selectFields[i];
			}
		}

		if ( not Len( Trim( selectDataArgs.orderBy ) ) ) {
			var relatedVia = getObjectPropertyAttribute( arguments.objectName, arguments.propertyName, "relatedVia", "" );
			if ( Len( Trim( relatedVia ) ) ) {
				selectDataArgs.orderBy = relatedVia & ".sort_order"
			}
		}

		return selectData( argumentCollection = selectDataArgs );
	}

	/**
	 * Synchronizes a record's related object data for a given property. Returns true on success, false otherwise.
	 * \n
	 * ${arguments}
	 * \n
	 * Example
	 * .......
	 * \n
	 * .. code-block:: java
	 * \n
	 * \tpresideObjectService.syncManyToManyData(
	 * \t      sourceObject   = "event"
	 * \t    , sourceProperty = "tags"
	 * \t    , sourceId       = rc.eventId
	 * \t    , targetIdList   = rc.tags // e.g. "635,1,52,24"
	 * \t);
	 *
	 * @sourceObject.hint   The object that contains the many-to-many property
	 * @sourceProperty.hint The name of the property that is defined as a many-to-many relationship
	 * @sourceId.hint       ID of the record who's related data we are to synchronize
	 * @targetIdList.hint   Comma separated list of IDs of records representing records in the related object
	 */
	public boolean function syncManyToManyData(
		  required string sourceObject
		, required string sourceProperty
		, required string sourceId
		, required string targetIdList
	) output=false autodoc=true {
		var prop = getObjectProperty( arguments.sourceObject, arguments.sourceProperty );
		var targetObject = prop.relatedTo ?: "";
		var pivotTable   = prop.relatedVia ?: "";

		if ( Len( Trim( pivotTable ) ) and Len( Trim( targetObject ) ) ) {
			var newRecords      = ListToArray( arguments.targetIdList );
			var anythingChanged = false;

			transaction {
				var currentRecords = selectData(
					  objectName   = pivotTable
					, selectFields = [ "#targetObject# as targetId", "sort_order" ]
					, filter       = { "#arguments.sourceObject#" = arguments.sourceId }
				);

				for( var record in currentRecords ) {
					if ( newRecords.find( record.targetId ) && newRecords.find( record.targetId ) == record.sort_order ) {
						ArrayDelete( newRecords, record.targetId );
					} else {
						anythingChanged = true;
						break;
					}
				}

				anythingChanged = anythingChanged || newRecords.len();

				if ( anythingChanged ) {
					deleteData(
						  objectName = pivotTable
						, filter     = { "#arguments.sourceObject#" = arguments.sourceId }
					);

					newRecords = ListToArray( arguments.targetIdList );
					for( var i=1; i <=newRecords.len(); i++ ) {
						insertData(
							  objectName    = pivotTable
							, data          = { "#arguments.sourceObject#" = arguments.sourceId, "#targetObject#" = newRecords[i], sort_order=i }
							, useVersioning = false
						);
					}
				}
			}
		}

		return true;
	}

	/**
	 * Returns a structure of many to many data for a given record. Each structure key represents a many-to-many type property on the object. The value for each key will be a comma separated list of IDs of the related data.
	 * \n
	 * ${arguments}
	 * \n
	 * Example
	 * .......
	 * \n
	 * .. code-block:: java
	 * \n
	 * \trelatedData = presideObjectService.getDeNormalizedManyToManyData(
	 * \t    objectName = "event"
	 * \t  , id         = rc.id
	 * \t);
	 * \n
	 * \t// the relatedData struct above might look like { tags = "C3635F77-D569-4D31-A794CA9324BC3E70,3AA27F08-819F-4C78-A8C5A97C897DFDE6" }
	 *
	 * @objectName.hint       Name of the object who's related data we wish to retrieve
	 * @id.hint               ID of the record who's related data we wish to retrieve
	 * @fromVersionTable.hint Whether or not to retrieve the data from the version history table for the object
	 * @maxVersion.hint       If retrieving from the version history, set a max version number
	 * @specificVersion.hint  If retrieving from the version history, set a specific version number to retrieve
	 */
	public struct function getDeNormalizedManyToManyData(
		  required string  objectName
		, required string  id
		,          boolean fromVersionTable = false
		,          string  maxVersion       = "HEAD"
		,          numeric specificVersion  = 0
	) output=false autodoc=true {
		var props          = getObjectProperties( arguments.objectName );
		var manyToManyData = {};

		for( var prop in props ) {
			if ( isManyToManyProperty( arguments.objectName, prop ) ) {

				var records = selectData(
					  objectName       = arguments.objectName
					, id               = arguments.id
					, selectFields     = [ "#prop#.id" ]
					, fromVersionTable = arguments.fromVersionTable
					, maxVersion       = arguments.maxVersion
					, specificVersion  = arguments.specificVersion
				);

				manyToManyData[ prop ] = records.recordCount ? ValueList( records.id ) : "";
			}
		}

		return manyToManyData;
	}

	/**
	 * Returns a summary query of all the versions of a given record (by ID),  optionally filtered by field name
	 *
	 * @objectName.hint Name of the object who's record we wish to retrieve the version history for
	 * @id.hint         ID of the record who's history we wish to view
	 * @fieldName.hint  Optional name of one of the object's property which which to filter the history. Doing so will show only versions in which this field changed.
	 *
	 */
	public query function getRecordVersions( required string objectName, required string id, string fieldName ) output=false autodoc=true {
		var args = {};

		for( var key in arguments ){ // we do this, because simply duplicating the arguments causes issues with the Argument type being more than a plain ol' structure
			args[ key ] = arguments[ key ];
		}

		args.append( {
			  objectName   = getVersionObjectName( arguments.objectName )
			, orderBy      = "_version_number desc"
			, useCache     = false
		} );

		if ( args.keyExists( "fieldName" ) ) {
			args.filter       = "id = :id and _version_changed_fields like :_version_changed_fields";
			args.filterParams = { id = arguments.id, _version_changed_fields = "%,#args.fieldName#,%" };
			args.delete( "fieldName" );
			args.delete( "id" );
		}

		return selectData( argumentCollection = args );
	}

	/**
	 * Performs a full database synchronisation with your Preside Data Objects. Creating new tables, fields and relationships as well
	 * as modifying and retiring existing ones.
	 * \n
	 * See :ref:`preside-objects-keeping-in-sync-with-db`.
	 * \n
	 * .. note::
	 * \t You are unlikely to need to call this method directly. See :doc:`/devguides/reloading`.
	 */
	public void function dbSync() output=false autodoc=true {
		_getSqlSchemaSynchronizer().synchronize(
			  dsns    = _getAllDsns()
			, objects = _getAllObjects()
		);
	}

	/**
	 * Reloads all the object definitions by reading them all from file.
	 * \n
	 * .. note::
	 * \t You are unlikely to need to call this method directly. See :doc:`/devguides/reloading`.
	 */
	public void function reload() output=false autodoc=true {
		_getObjectCache().clearAll();
		_getDefaultQueryCache().clearAll();
		_loadObjects();
	}

	/**
	 * Returns an array of names for all of the registered objects, sorted alphabetically (ignoring case)
	 */
	public array function listObjects() autodoc=true output=false {
		var objects     = _getAllObjects();
		var objectNames = [];

		for( var objectName in objects ){
			if ( !IsSimpleValue( objects[ objectName ].instance ?: "" ) ) {
				objectNames.append( objectName );
			}
		}

		ArraySort( objectNames, "textnocase" );

		return objectNames;
	}

	/**
	 * Returns whether or not the passed object name has been registered
	 *
	 * @objectName.hint Name of the object that you wish to check the existance of
	 */
	public boolean function objectExists( required string objectName ) output=false autodoc=true {
		var objects = _getAllObjects();

		return StructKeyExists( objects, arguments.objectName );
	}

	/**
	 * Returns whether or not the passed field exists on the passed object
	 *
	 * @objectName.hint Name of the object who's field you wish to check
	 * @fieldName.hint  Name of the field you wish to check the existance of
	 */
	public boolean function fieldExists( required string objectName, required string fieldName ) output=false autodoc=true {
		var obj = _getObject( arguments.objectName );

		return StructKeyExists( obj.meta.properties, arguments.fieldName );
	}

	/**
	 * Returns an arbritary attribute value that is defined on the object's :code:`component` tag.
	 * \n
	 * ${arguments}
	 * \n
	 * Example
	 * .......
	 * \n
	 * .. code-block:: java
	 * \n
	 * \teventLabelField = presideObjectService.getObjectAttribute(
	 * \t      objectName    = "event"
	 * \t    , attributeName = "labelField"
	 * \t    , defaultValue  = "label"
	 * \t);
	 *
	 * @objectName.hint    Name of the object who's attribute we wish to get
	 * @attributeName.hint Name of the attribute who's value we wish to get
	 * @defaultValue.hint  Default value for the attribute, should it not exist
	 *
	 */
	public any function getObjectAttribute( required string objectName, required string attributeName, string defaultValue="" ) output=false autodoc=true {
		var obj = _getObject( arguments.objectName );

		return obj.meta[ arguments.attributeName ] ?: arguments.defaultValue;
	}

	/**
	 * Returns an arbritary attribute value that is defined on a specified property for an object.
	 * \n
	 * ${arguments}
	 * \n
	 * Example
	 * .......
	 * \n
	 * .. code-block:: java
	 * \n
	 * \tmaxLength = presideObjectService.getObjectPropertyAttribute(
	 * \t      objectName    = "event"
	 * \t    , propertyName  = "name"
	 * \t    , attributeName = "maxLength"
	 * \t    , defaultValue  = 200
	 * \t);
	 *
	 * @objectName.hint    Name of the object who's property attribute we wish to get
	 * @objectName.hint    Name of the property who's attribute we wish to get
	 * @attributeName.hint Name of the attribute who's value we wish to get
	 * @defaultValue.hint  Default value for the attribute, should it not exist
	 *
	 */
	public string function getObjectPropertyAttribute( required string objectName, required string propertyName, required string attributeName, string defaultValue="" ) output=false autodoc=true {
		var obj = _getObject( arguments.objectName );

		return obj.meta.properties[ arguments.propertyName ][ arguments.attributeName ] ?: arguments.defaultValue;
	}


	/**
	 * This method, returns the object name that can be used to reference the version history object
	 * for a given object.
	 *
	 * @sourceObjectName.hint Name of the object who's version object name we wish to retrieve
	 */
	public string function getVersionObjectName( required string sourceObjectName ) output=false autodoc=true {
		var obj = _getObject( arguments.sourceObjectName );

		return obj.meta.versionObjectName;
	}

	/**
	 * Returns whether or not the given object is using the versioning system
	 *
	 * @objectName.hint Name of the object you wish to check
	 */
	public boolean function objectIsVersioned( required string objectName ) output=false autodoc=true {
		var obj = _getObject( objectName );

		return IsBoolean( obj.meta.versioned ?: "" ) && obj.meta.versioned;
	}

	/**
	 * Returns the next available version number that can
	 * be used for saving a new version record.
	 * \n
	 * This is an auto incrementing integer that is global to all versioning tables
	 * in the system.
	 */
	public numeric function getNextVersionNumber() output=false autodoc=true {
		return _getVersioningService().getNextVersionNumber();
	}

	/**
	 * Returns whether or not the given object is using the site tenancy system, see :ref:`presideobjectssites`
	 *
	 * @objectName.hint Name of the object you wish to check
	 */
	public boolean function objectIsUsingSiteTenancy( required string objectName ) output=false autodoc=true {
		var obj = _getObject( objectName );

		return IsBoolean( obj.meta.siteFiltered ?: "" ) && obj.meta.siteFiltered;
	}


	public any function getObjectProperties( required string objectName ) output=false {
		return _getObject( arguments.objectName ).meta.properties;
	}

	public any function getObjectProperty( required string objectName, required string propertyName ) output=false {
		return _getObject( arguments.objectName ).meta.properties[ arguments.propertyName ];
	}


	public boolean function isPageType( required string objectName ) output=false {
		var objMeta = _getObject( arguments.objectName ).meta;

		return IsBoolean( objMeta.isPageType ?: "" ) && objMeta.isPageType;
	}

	public string function getResourceBundleUriRoot( required string objectName ) output=false {
		if ( objectExists( arguments.objectName ) ) {
			return ( isPageType( arguments.objectName ) ? "page-types" : "preside-objects" ) & ".#arguments.objectName#:";
		}
		return "cms:";
	}

	public boolean function isManyToManyProperty( required string objectName, required string propertyName ) output=false {
		return getObjectPropertyAttribute( arguments.objectName, arguments.propertyName, "relationship", "" ) == "many-to-many";
	}

	public any function getDbAdapterForObject( required string objectName ) output=false {
		var obj = _getObject( arguments.objectName ).meta;

		return _getAdapter( obj.dsn );
	}

	public array function listForeignObjectsBlockingDelete( required string objectName, required any recordId ) output=false {
		var obj   = _getObject( objectName=arguments.objectName );
		var joins = _getRelationshipGuidance().getObjectRelationships( arguments.objectName );
		var foreignObjName  = "";
		var join  = "";
		var blocking = [];
		var filter = {};
		var recordCount = 0;
		var relatedKey = "";

		for( foreignObjName in joins ){
			for( join in joins[ foreignObjName ] ) {
				if ( join.type == "one-to-many" && join.ondelete !== "cascade" ) {
					filter = { "#join.fk#" = arguments.recordId };
					recordCount = selectData( objectName=foreignObjName, selectFields=["count(*) as record_count"], filter=filter, useCache=false ).record_count;

					if ( recordCount ) {
						ArrayAppend( blocking, { objectName=foreignObjName, recordcount=recordcount, fk=join.fk } );
					}
				}
			}
		}

		return blocking;
	}

	public numeric function deleteRelatedData( required string objectName, required any recordId ) output=false {
		var blocking       = listForeignObjectsBlockingDelete( argumentCollection = arguments );
		var totalDeleted   = 0;
		var blocker        = "";

		transaction {
			try {
				for( blocker in blocking ){
					totalDeleted += deleteData(
						  objectName = blocker.objectName
						, filter     = { "#blocker.fk#" = arguments.recordId }
					);
				}
			} catch( database e ) {
				throw(
					  type    = "PresideObjectService.CascadeDeleteTooDeep"
					, message = "A cascading delete of a [#arguments.objectName#] record was prevented due to too many levels of cascade."
					, detail  = "Preside will only allow a single level of cascaded deletes"
				);
			}
		}

		return totalDeleted;
	}

	public string function getDefaultFormControlForPropertyAttributes( string type="string", string dbType="varchar", string relationship="none", string relatedTo="", numeric maxLength=0 ) output=false {
		switch( arguments.relationship ){
			case "many-to-one" :
				return arguments.relatedTo == "asset" ? "assetPicker" : "manyToOneSelect";
			case "many-to-many":
				return arguments.relatedTo == "asset" ? "assetPicker" : "manyToManySelect";
		}

		switch ( arguments.type ) {
			case "numeric":
				return "spinner";
			case "boolean":
				return "yesNoSwitch";
			case "date":
				return "datePicker";
		}

		switch( arguments.dbType ){
			case "text":
			case "longtext":
			case "clob":
				return "richeditor";
		}

		if ( maxLength gte 200 ) {
			return "textarea";
		}

		return "textinput";
	}

// PRIVATE HELPERS
	private void function _loadObjects() output=false {
		var objectPaths   = _getAllObjectPaths();
		var cache         = _getObjectCache();
		var objPath       = "";
		var objects       = {};
		var obj           = "";
		var objName       = "";
		var dsns          = {};

		for( objPath in objectPaths ){
			objName      = ListLast( objPath, "/" );
			obj          = {};
			obj.instance = CreateObject( "component", objPath );
			obj.meta     = _getObjectReader().readObject( obj.instance );

			objects[ objName ] = objects[ objName ] ?: [];
			objects[ objName ].append( obj );
			dsns[ obj.meta.dsn ] = 1;
		}
		if ( StructCount( objects ) ) {
			objects = _mergeObjects( objects );
			_getRelationshipGuidance().setupRelationships( objects );
			_getVersioningService().setupVersioningForVersionedObjects( objects, StructKeyArray( dsns )[1] );
		}

		cache.set( "PresideObjectService: objects", objects );
		cache.set( "PresideObjectService: dsns"   , StructKeyArray( dsns ) );
	}

	private struct function _mergeObjects( required struct unMergedObjects ) output=false {
		var merged = {};
		var merger = new Merger();

		for( var objName in unMergedObjects ) {
			merged[ objName ] = unMergedObjects[ objName ][ 1 ];

			for( var i=2; i lte unMergedObjects[ objName ].len(); i++ ) {
				merged[ objName ] = new Merger().mergeObjects( merged[ objName ], unMergedObjects[ objName ][ i ] );
			}
		}
		return merged;
	}

	private struct function _getAllObjects() output=false {
		var cache = _getObjectCache();

		if ( not cache.lookup( "PresideObjectService: objects" ) ) {
			_loadObjects();
		}

		return _getObjectCache().get( "PresideObjectService: objects" );
	}

	private array function _getAllDsns() output=false {
		var cache = _getObjectCache();

		if ( not cache.lookup( "PresideObjectService: dsns" ) ) {
			_loadObjects();
		}

		return _getObjectCache().get( "PresideObjectService: dsns" );
	}

	private struct function _getObject( required string objectName ) output=false {
		var objects = _getAllObjects();

		if ( not StructKeyExists( objects, arguments.objectName ) ) {
			throw( type="PresideObjectService.missingObject", message="Object [#arguments.objectName#] does not exist" );
		}

		return objects[ arguments.objectName ];
	}

	private array function _getAllObjectPaths() output=false {
		var dirs        = _getObjectDirectories();
		var dir         = "";
		var dirExpanded = "";
		var files       = "";
		var file        = "";
		var paths       = [];
		var path        = "";
		for( dir in dirs ) {
			files = DirectoryList( path=dir, recurse=true, filter="*.cfc" );
			dirExpanded = ExpandPath( dir );

			for( file in files ) {
				path = dir & Replace( file, dirExpanded, "" );
				path = ListDeleteAt( path, ListLen( path, "." ), "." );
				path = ListChangeDelims( path, "/", "\" );

				ArrayAppend( paths, path );
			}
		}

		return paths;
	}

	private array function _convertDataToQueryParams( required string objectName, required struct columnDefinitions, required struct data, required any dbAdapter, string prefix="", string tableAlias="" ) {
		var key        = "";
		var params     = [];
		var param      = "";
		var objName = "";
		var cols       = "";
		var i          = 0;
		var paramName  = "";
		var dataType   = "";

		for( key in arguments.data ){
			if ( ListLen( key, "." ) == 2 && ListFirst( key, "." ) != arguments.tableAlias ) {

				objName = _resolveObjectNameFromColumnJoinSyntax( startObject = arguments.objectName, joinSyntax = ListFirst( key, "." ) );

				if ( objectExists( objName ) ) {
					cols = _getObject( objName ).meta.properties;
				}
			} else {
				cols = arguments.columnDefinitions;
			}

			paramName = arguments.prefix & Replace( key, ".", "__", "all" );
			dataType  = arguments.dbAdapter.sqlDataTypeToCfSqlDatatype( cols[ ListLast( key, "." ) ].dbType );


			if ( not StructKeyExists( arguments.data,  key ) ) { // should use IsNull() arguments.data[key] but bug in Railo prevents this
				param = {
					  name  = paramName
					, value = NullValue()
					, type  = dataType
					, null  = true
				};

				ArrayAppend( params, param );
			} else if ( IsArray( arguments.data[ key ] ) ) {
				for( i=1; i lte ArrayLen(  arguments.data[ key ] ); i++ ){
					param = {
						  name  = paramName & "__" & i
						, value = arguments.data[ key ][ i ]
						, type  = dataType
					};

					ArrayAppend( params, param );
				}

			} else {
				param = {
					  name  = paramName
					, value = arguments.data[ key ]
					, type  = dataType
				};

				ArrayAppend( params, param );
			}

		}

		return params;
	}

	private array function _convertUserFilterParamsToQueryParams( required struct columnDefinitions, required struct params, required any dbAdapter ) output=false {
		var key        = "";
		var params     = [];
		var param      = "";
		var objectName = "";
		var cols       = "";
		var i          = 0;
		var paramName  = "";
		var dataType   = "";

		for( key in arguments.params ){
			param     = arguments.params[ key ];
			paramName = Replace( key, ".", "__", "all" );

			if ( IsStruct( param ) ) {
				StructAppend( param, { name=paramName } );
			} else {
				param = {
					  name  = paramName
					, value = param
				};
			}

			if ( not StructKeyExists( param, "type" ) ) {
				if ( ListLen( key, "." ) eq 2 ) {
					cols = _getObject( ListFirst( key, "." ) ).meta.properties;
				} else {
					cols = arguments.columnDefinitions;
				}

				param.type = arguments.dbAdapter.sqlDataTypeToCfSqlDatatype( cols[ ListLast( key, "." ) ].dbType );
			}

			ArrayAppend( params, param );
		}

		return params;
	}

	private array function _extractForeignObjectsFromArguments(
		  required string objectName
		,          any    filter       = {}
		,          struct data         = {}
		,          array  selectFields = []
		,          string orderBy      = ""

	) output=false {
		var key        = "";
		var cache      = _getObjectCache();
		var cacheKey   = "Detected foreign objects for generated SQL. Obj: #arguments.objectName#. Data: #StructKeyList( arguments.data )#. Fields: #ArrayToList( arguments.selectFields )#. Order by: #arguments.orderBy#. Filter: #IsStruct( arguments.filter ) ? StructKeyList( arguments.filter ) : arguments.filter#"
		var objects    = cache.get( cacheKey );

		if ( not IsNull( objects ) ) {
			return objects;
		}

		var all        = Duplicate( arguments.data );
		var fieldRegex = _getAlaisedFieldRegex();
		var field      = "";
		var matches    = "";
		var match      = "";

		objects = {}

		if ( IsStruct( arguments.filter ) ) {
			StructAppend( all, arguments.filter );
		}

		for( key in all ) {
			if ( ListLen( key, "." ) eq 2 ) {
				objects[ ListFirst( key, "." ) ] = 1;
			}
		}

		for( field in arguments.selectFields ){
			matches = _reSearch( fieldRegex, field );
			if ( StructKeyExists( matches, "$2" ) ) {
				for( match in matches.$2 ){
					objects[ match ] = 1;
				}
			}
		}
		for( field in ListToArray( arguments.orderBy ) ){
			matches = _reSearch( fieldRegex, ListFirst( field, " " ) );
			if ( StructKeyExists( matches, "$2" ) ) {
				for( match in matches.$2 ){
					objects[ match ] = 1;
				}
			}
		}
		if ( isSimpleValue( arguments.filter ) ) {
			matches = _reSearch( fieldRegex, arguments.filter );
			if ( StructKeyExists( matches, "$2" ) ) {
				for( match in matches.$2 ){
					objects[ match ] = 1;
				}
			}
		}


		StructDelete( objects, arguments.objectName );
		objects = StructKeyArray( objects );

		cache.set( cacheKey, objects );

		return objects;
	}

	private array function _convertObjectJoinsToTableJoins( required array objectJoins ) output=false {
		var tableJoins = [];
		var objJoin = "";
		var objects = _getAllObjects();
		var tableJoin = "";

		for( objJoin in arguments.objectJoins ){
			var join = {
				  tableName         = objects[ objJoin.joinToObject ].meta.tableName
				, tableAlias        = objJoin.tableAlias ?: objJoin.joinToObject
				, tableColumn       = objJoin.joinToProperty
				, joinToTable       = objJoin.joinFromObject
				, joinToColumn      = objJoin.joinFromProperty
				, type              = objJoin.type
			};

			if ( IsBoolean( objJoin.addVersionClause ?: "" ) && objJoin.addVersionClause ) {
				join.additionalClauses = "#join.tableAlias#._version_number = #join.joinToTable#._version_number";
			}

			tableJoins.append( join );
		}

		return tableJoins;
	}

	private query function _selectFromVersionTables(
		  required string  objectName
		, required string  originalTableName
		, required array   joins
		, required array   selectFields
		, required string  maxVersion
		, required numeric specificVersion
		, required any     filter
		, required array   params
		, required string  orderBy
		, required string  groupBy
		, required numeric maxRows
		, required numeric startRow
	) output=false {
		var adapter              = getDbAdapterForObject( arguments.objectName );
		var versionObj           = _getObject( getVersionObjectName( arguments.objectName ) ).meta;
		var versionTableName     = versionObj.tableName;
		var alteredJoins         = _alterJoinsToUseVersionTables( arguments.joins, arguments.originalTableName, versionTableName );
		var compiledSelectFields = Duplicate( arguments.selectFields );
		var compiledFilter       = Duplicate( arguments.filter );
		var sql                  = "";
		var versionFilter        = "";
		var versionCheckJoin     = "";
		var versionCheckFilter   = "";

		if ( not ArrayLen( arguments.selectFields ) ) {
			compiledSelectFields = _dbFieldListToSelectFieldsArray( versionObj.dbFieldList, arguments.objectName, adapter );
		}

		if ( arguments.specificVersion ) {
			versionFilter = { "#arguments.objectName#._version_number" = arguments.specificVersion };
			compiledFilter = _mergeFilters( compiledFilter, versionFilter, adapter, arguments.objectName );

			arguments.params = _arrayMerge( arguments.params, _convertDataToQueryParams(
				  objectName        = arguments.objectName
				, columnDefinitions = versionObj.properties
				, data              = versionFilter
				, dbAdapter         = adapter
				, tableAlias        = arguments.objectName
			) );
		} else {
			versionCheckJoin   = _getVersionCheckJoin( versionTableName, arguments.objectName, adapter );
			versionCheckFilter = "_latestVersionCheck.id is null";

			if ( ReFind( "^[1-9][0-9]*$", arguments.maxVersion ) ) {
				versionCheckJoin.additionalClauses &= " and _latestVersionCheck._version_number <= #arguments.maxVersion#";
				versionCheckFilter &= " and #arguments.objectName#._version_number <= #arguments.maxVersion#";
			}
			ArrayAppend( alteredJoins, versionCheckJoin );

			compiledFilter = _mergeFilters( compiledFilter, versionCheckFilter, adapter, arguments.objectName );
		}

		sql = adapter.getSelectSql(
			  tableName     = versionTableName
			, tableAlias    = arguments.objectName
			, selectColumns = compiledSelectFields
			, filter        = compiledFilter
			, joins         = alteredJoins
			, orderBy       = arguments.orderBy
			, groupBy       = arguments.groupBy
			, maxRows       = arguments.maxRows
			, startRow      = arguments.startRow
		);

		return _runSql( sql=sql, dsn=versionObj.dsn, params=arguments.params );
	}

	private struct function _getVersionCheckJoin( required string tableName, required string tableAlias, required any adapter ) output=false {
		return {
			  tableName         = arguments.tableName
			, tableAlias        = "_latestVersionCheck"
			, tableColumn       = "id"
			, joinToTable       = arguments.tableAlias
			, joinToColumn      = "id"
			, type              = "left"
			, additionalClauses = "#adapter.escapeEntity( '_latestVersionCheck' )#.#adapter.escapeEntity( '_version_number' )# > #adapter.escapeEntity( arguments.tableAlias )#.#adapter.escapeEntity( '_version_number' )#"
		}
	}

	private array function _alterJoinsToUseVersionTables(
		  required array  joins
		, required string originalTableName
		, required string versionTableName
	) output=false {
		var manyToManyObjects = {};
		for( var join in arguments.joins ){
			if ( Len( Trim( join.manyToManyProperty ?: "" ) ) ) {
				manyToManyObjects[ join.joinToObject ] = 1;
			}
		}

		for( var obj in manyToManyObjects ){
			if ( !objectIsVersioned( obj ) ) {
				StructDelete( manyToManyObjects, obj );
			}
		}

		if ( manyToManyObjects.len() ) {
			for( var join in arguments.joins ){
				if ( manyToManyObjects.keyExists( join.joinFromObject ) ) {
					join.joinFromObject = getVersionObjectName( join.joinFromObject );
				}
				if ( manyToManyObjects.keyExists( join.joinToObject ) ) {
					join.joinToObject = getVersionObjectName( join.joinToObject );
					join.addVersionClause = true;
				}
			}
		}

		return _convertObjectJoinsToTableJoins( arguments.joins );
	}

	private array function _dbFieldListToSelectFieldsArray( required string fieldList, required string tableAlias, required any dbAdapter ) output=false {
		var fieldArray   = ListToArray( arguments.fieldList );
		var escapedAlias = dbAdapter.escapeEntity( arguments.tableAlias );

		for( var i=1; i <= fieldArray.len(); i++ ){
			fieldArray[i] = escapedAlias & "." & dbAdapter.escapeEntity( fieldArray[i] );
		}

		return fieldArray;
	}

	private string function _mergeFilters( required any filter1, required any filter2, required any dbAdapter, required string tableAlias ) output=false {
		var parsed1 = arguments.dbAdapter.getClauseSql( arguments.filter1, arguments.tableAlias );
		var parsed2 = arguments.dbAdapter.getClauseSql( arguments.filter2, arguments.tableAlias );

		parsed1 = ReReplace( parsed1, "^\s*where ", "" );
		parsed2 = ReReplace( parsed2, "^\s*where ", "" );

		if ( Len( Trim( parsed1 ) ) && Len( Trim( parsed2 ) ) ) {
			return "(" & parsed1 & ") and (" & parsed2 & ")";
		}

		return Len( Trim( parsed1 ) ) ? parsed1 : parsed2;
	}

	private string function _generateNewIdWhenNecessary( required string generator ) output=false {
		switch( arguments.generator ){
			case "UUID": return CreateUUId();
		}

		return "";
	}

	private array function _arrayMerge( required array arrayA, required array arrayB ) output=false {
		var newArray = Duplicate( arguments.arrayA );
		var node     = "";

		for( node in arguments.arrayB ){
			ArrayAppend( newArray, node );
		}

		return newArray;
	}

	private string function _getAlaisedFieldRegex() output=false {
		if ( not StructKeyExists( this, "_aliasedFieldRegex" ) ) {
			var entities = {};

			for( var objName in _getAllObjects() ){
				entities[ objName ] = 1;

				for( var propertyName in getObjectProperties( objName ) ) {
					entities[ propertyName ] = 1;
				}
			}
			entities = StructKeyList( entities, "|" );

			_aliasedFieldRegex = "(^|\s|,|\(,\))((#entities#)(\$(#entities#))*)\.([a-zA-Z_][a-zA-Z0-9_]*)(\s|$|\)|,)";
		}

		return _aliasedFieldRegex;
	}

	private struct function _reSearch( required string regex, required string text ) output=false {
		var final 	= StructNew();
		var pos		= 1;
		var result	= ReFindNoCase( arguments.regex, arguments.text, pos, true );
		var i		= 0;

		while( ArrayLen(result.pos) GT 1 ) {
			for(i=2; i LTE ArrayLen(result.pos); i++){
				if(not StructKeyExists(final, '$#i-1#')){
					final['$#i-1#'] = ArrayNew(1);
				}

				if ( result.pos[i] ) {
					ArrayAppend( final['$#i-1#'], Mid( arguments.text, result.pos[i], result.len[i] ) );
				} else {
					ArrayAppend( final['$#i-1#'], "" );
				}
			}
			pos = result.pos[2] + 1;
			result	= ReFindNoCase( arguments.regex, arguments.text, pos, true );
		} ;

		return final;
	}

	private boolean function _isEmptyFilter( required any filter ) output=false {
		if ( IsStruct( arguments.filter ) ) {
			return StructIsEmpty( arguments.filter );
		}

		if ( IsSimpleValue( arguments.filter ) ) {
			return not Len( Trim( arguments.filter ) );
		}

		return true;
	}

	private void function _recordCacheSoThatWeCanClearThemWhenDataChanges(
		  required string objectName
		, required string cacheKey
		, required any    filter
		, required struct filterParams
		, required array  joinTargets
	) output=false {
		var cacheMaps = _getCacheMaps();
		var objId     = "";
		var id        = "";
		var joinObj   = "";

		if ( not StructKeyExists( cacheMaps, arguments.objectName ) ) {
			cacheMaps[ arguments.objectName ] = {
				__complexFilter = {}
			};
		}

		if ( IsStruct( arguments.filter ) and StructKeyExists( arguments.filter, "id" ) ) {
			objId = arguments.filter.id;
		} elseif ( StructKeyExists( arguments.filterParams, "id" ) ) {
			objId = arguments.filterParams.id;
		}

		if ( IsStruct( objId ) ) {
			if ( Len( Trim( objId.value ?: "" ) ) ) {
				objId = ( objId.list ?: false ) ? ListToArray( objId.value, objId.separator ?: "," ) : [ objId.value ];
			}
		}

		if ( IsArray( objId ) ) {
			for( id in objId ){
				cacheMaps[ arguments.objectName ][ id ][ arguments.cacheKey ] = 1;
			}
		} elseif ( IsSimpleValue( objId ) and Len( Trim( objId) ) ) {
			cacheMaps[ arguments.objectName ][ objId ][ arguments.cacheKey ] = 1;
		} else {
			cacheMaps[ arguments.objectName ].__complexFilter[ arguments.cacheKey ] = 1;
		}

		for( joinObj in arguments.joinTargets ) {
			if ( not StructKeyExists( cacheMaps, joinObj ) ) {
				cacheMaps[ joinObj ] = {
					__complexFilter = {}
				};
			}
			cacheMaps[ joinObj ].__complexFilter[ arguments.cacheKey ] = 1;
		}
	}

	private void function _clearRelatedCaches(
		  required string  objectName
		, required any     filter
		, required struct  filterParams
		,          boolean clearSingleRecordCaches = true
	) output=false {
		var cacheMaps   = _getCacheMaps();
		var keysToClear = "";
		var objIds      = "";
		var objId       = "";

		if ( StructKeyExists( cacheMaps, arguments.objectName ) ) {
			keysToClear = StructKeyList( cacheMaps[ arguments.objectName ].__complexFilter );

			if ( IsStruct( arguments.filter ) and StructKeyExists( arguments.filter, "id" ) ) {
				objIds = arguments.filter.id;
			} elseif ( StructKeyExists( arguments.filterParams, "id" ) ) {
				objIds = arguments.filterParams.id;
			}

			if ( IsSimpleValue( objIds ) ) {
				objIds = ListToArray( objIds );
			}

			if ( IsArray( objIds ) and ArrayLen( objIds ) ) {
				for( objId in objIds ){
					if ( StructKeyExists( cacheMaps[ arguments.objectName ], objId ) ) {
						keysToClear = ListAppend( keysToClear, StructKeyList( cacheMaps[ arguments.objectName ][ objId ] ) );
						StructDelete( cacheMaps[ arguments.objectName ], objId );
					}
				}
				StructClear( cacheMaps[ arguments.objectName ].__complexFilter );
			} elseif ( arguments.clearSingleRecordCaches ) {
				for( objId in cacheMaps[ arguments.objectName ] ) {
					if ( objId neq "__complexFilter" ) {
						keysToClear = ListAppend( keysToClear, StructKeyList( cacheMaps[ arguments.objectName ][ objId ] ) );
					}
				}
				StructDelete( cacheMaps, arguments.objectName );
			}

			if ( ListLen( keysToClear ) ) {
				_getDefaultQueryCache().clearMulti( keysToClear );
			}
		}
	}

	private array function _parseSelectFields( required string objectName, required array selectFields ) output=false {
		for( var i=1; i <=arguments.selectFields.len(); i++ ){
			var objName = "";
			var match   = ReFindNoCase( "([\S]+\.)?\$\{labelfield\}", arguments.selectFields[i], 1, true );

			match = match.len[1] ? Mid( arguments.selectFields[i], match.pos[1], match.len[1] ) : "";

			if ( Len( Trim( match ) ) ) {
				var labelField = "";
				if ( ListLen( match, "." ) == 1 ) {
					objName = arguments.objectName;
				} else {
					objName = _resolveObjectNameFromColumnJoinSyntax( startObject=arguments.objectName, joinSyntax=ListFirst( match, "." ) );
				}

				labelField = getObjectAttribute( objName, "labelfield", "label" );
				if ( !Len( labelField ) ) {
					throw( type="PresideObjectService.no.label.field", message="The object [#objName#] has no label field" );
				}

				arguments.selectFields[i] = Replace( arguments.selectFields[i], "${labelfield}", labelField, "all" );
			}
		}

		return arguments.selectFields;
	}

	private string function _resolveObjectNameFromColumnJoinSyntax( required string startObject, required string joinSyntax ) output=false {
		var currentObject = arguments.startObject;
		var columns       = _getObject( currentObject ).meta.properties;
		var steps         = ListToArray( arguments.joinSyntax, "$" );

		for( var i=1; i <= steps.len(); i++ ){
			var step = steps[i];

			if ( columns.keyExists( step ) && ( columns[step].relatedTo ?: "none" ) !== "none" ) {
				currentObject = columns[step].relatedTo;
			} elseif ( objectExists( step ) ) {
				currentObject = step;
			} else {
				return ""; // cannot resolve
			}

			if ( i < steps.len() ) {
				columns = _getObject( currentObject ).meta.properties;
			}
		}

		return currentObject;
	}

	private string function _getActiveSiteId() output=false {
		var site = _getColdboxRequestContext().getSite();

		return ( site.id ?: "" );
	}

	private struct function _prepareFilter(
		  required string objectName
		, required string id
		, required any    filter
		, required struct filterParams
		, required any    adapter
		, required struct columnDefinitions
	) output=false {
		var result = "";

		if ( Len( Trim( arguments.id ) ) ) {
			arguments.filter = { id = arguments.id };
		}

		if ( objectIsUsingSiteTenancy( arguments.objectName ) ) {
			result = _addSiteFilterForObjectsThatUseSiteTenancy( argumentCollection=arguments );
		} else {
			result = {
				  filter       = arguments.filter
				, filterParams = arguments.filterParams
			};
		}

		if ( IsStruct( result.filter ) ) {
			result.params = _convertDataToQueryParams(
				  objectName        = arguments.objectName
				, columnDefinitions = arguments.columnDefinitions
				, data              = result.filter
				, dbAdapter         = adapter
			);
		} else {
			result.params = _convertUserFilterParamsToQueryParams(
				  columnDefinitions = arguments.columnDefinitions
				, params            = result.filterParams
				, dbAdapter         = adapter
			);
		}

		return result;
	}

	private struct function _addSiteFilterForObjectsThatUseSiteTenancy( required string objectName, required any filter, required struct filterParams, required any adapter ) output=false {
		var site   = _getActiveSiteId();
		var result = {
			  filter       = arguments.filter
			, filterParams = arguments.filterParams
		};

		if ( Len( Trim( site ) ) ) {
			if ( IsStruct( arguments.filter ) ) {
				result.filter.site = site;
			} else {
				result.filter = _mergeFilters( result.filter, "#arguments.objectName#.site = :site", arguments.adapter, arguments.objectName );
				result.filterParams.site = site;
			}
		}

		return result;
	}

	private struct function _addDefaultValuesToDataSet( required string objectName, required struct data ) output=false {
		var props   = getObjectProperties( arguments.objectName );
		var newData = Duplicate( arguments.data );

		for( var propName in props ){
			if ( !StructKeyExists( arguments.data, propName ) && Len( Trim( props[ propName ].default ?: "" ) ) ) {
				var default = props[ propName ].default;
				switch( ListFirst( default, ":" ) ) {
					case "cfml":
						newData[ propName ] = Evaluate( ListRest( default, ":" ) );
					break;
					case "closure":
						var func = Evaluate( ListRest( default, ":" ) );
						newData[ propName ] = func( arguments.data );
					break;
					case "method":
						var obj = getObject( arguments.objectName );

						newData[ propName ] = obj[ ListRest( default, ":" ) ]( arguments.data );
					break;
					default:
						newData[ propName ] = default;
				}
			}
		}

		return newData;
	}

// SIMPLE PRIVATE PROXIES
	private any function _getAdapter() output=false {
		return _getAdapterFactory().getAdapter( argumentCollection = arguments );
	}

	private any function _runSql() output=false {
		return _getSqlRunner().runSql( argumentCollection = arguments );
	}

// GETTERS AND SETTERS
	private array function _getObjectDirectories() output=false {
		return _objectDirectories;
	}
	private void function _setObjectDirectories( required array objectDirectories ) output=false {
		_objectDirectories = arguments.objectDirectories;
	}

	private any function _getObjectReader() output=false {
		return _objectReader;
	}
	private void function _setObjectReader( required any objectReader ) output=false {
		_objectReader = arguments.objectReader;
	}

	private any function _getSqlSchemaSynchronizer() output=false {
		return _sqlSchemaSynchronizer;
	}
	private void function _setSqlSchemaSynchronizer( required any sqlSchemaSynchronizer ) output=false {
		_sqlSchemaSynchronizer = arguments.sqlSchemaSynchronizer;
	}

	private any function _getAdapterFactory() output=false {
		return _adapterFactory;
	}
	private void function _setAdapterFactory( required any adapterFactory ) output=false {
		_adapterFactory = arguments.adapterFactory;
	}

	private any function _getSqlRunner() output=false {
		return _sqlRunner;
	}
	private void function _setSqlRunner( required any sqlRunner ) output=false {
		_sqlRunner = arguments.sqlRunner;
	}

	private any function _getRelationshipGuidance() output=false {
		return _relationshipGuidance;
	}
	private void function _setRelationshipGuidance( required any relationshipGuidance ) output=false {
		_relationshipGuidance = arguments.relationshipGuidance;
	}

	private any function _getVersioningService() output=false {
		return _versioningService;
	}
	private void function _setVersioningService( required any versioningService ) output=false {
		_versioningService = arguments.versioningService;
	}

	private any function _getPresideObjectDecorator() output=false {
		return _presideObjectDecorator;
	}
	private void function _setPresideObjectDecorator( required any presideObjectDecorator ) output=false {
		_presideObjectDecorator = arguments.presideObjectDecorator;
	}

	private any function _getObjectCache() output=false {
		return _objectCache;
	}
	private void function _setObjectCache( required any objectCache ) output=false {
		_objectCache = arguments.objectCache;
	}

	private any function _getDefaultQueryCache() output=false {
		return _defaultQueryCache;
	}
	private void function _setDefaultQueryCache( required any defaultQueryCache ) output=false {
		_defaultQueryCache = arguments.defaultQueryCache;
	}

	private struct function _getCacheMaps() output=false {
		return _cacheMaps;
	}
	private void function _setCacheMaps( required struct cacheMaps ) output=false {
		_cacheMaps = arguments.cacheMaps;
	}

	private any function _getColdboxController() output=false {
		return _coldboxController;
	}
	private void function _setColdboxController( required any coldboxController ) output=false {
		_coldboxController = arguments.coldboxController;
	}

	private any function _getColdboxRequestContext() output=false {
		return _getColdboxController().getRequestContext();
	}
}