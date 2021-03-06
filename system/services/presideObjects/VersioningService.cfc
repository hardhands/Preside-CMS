component output=false singleton=true {

// CONSTRUCTOR
	/**
	 * @presideObjectService.inject PresideObjectService
	 * @coldboxController.inject    coldbox
	 */
	public any function init( required any presideObjectService, required any coldboxController ) output=false {
		_setPresideObjectService( arguments.presideObjectService );
		_setColdboxController( arguments.coldboxController );

		return this;
	}

// PUBLIC API METHODS
	public void function setupVersioningForVersionedObjects( required struct objects, required string primaryDsn ) output=false {
		var versionedObjects = {};

		for( var objectName in objects ){
			var obj = objects[ objectName ];

			if ( IsBoolean( obj.meta.versioned ?: "" ) && obj.meta.versioned ) {
				var versionObjectName = "vrsn_" & objectName;
				var objMeta = duplicate( obj.meta );

				obj.meta.versionObjectName = versionObjectName;

				objMeta.versioned = false;
				objMeta.tableName = "_version_" & objMeta.tableName;

				_removeUniqueIndexes( objMeta );
				_removeRelationships( objMeta );
				_addAdditionalVersioningPropertiesToVersionObject( objMeta, versionObjectName );

				versionedObjects[ versionObjectName ] = { meta = objMeta, instance="auto_created" };
			}
		}

		StructAppend( objects, versionedObjects );

		if ( StructCount( versionedObjects ) ) {
			objects[ "version_number_sequence" ] = _createVersionNumberSequenceObject( primaryDsn );
		}

	}

	public numeric function getNextVersionNumber() output=false {
		return _getPresideObjectService().insertData( objectName="version_number_sequence", data={} );
	}

	public numeric function saveVersionForInsert(
		  required string  objectName
		, required struct  data
		, required struct  manyToManyData
		,          string  versionAuthor = _getLoggedInUserId()
		,          numeric versionNumber = getNextVersionNumber()
	) output=false {
		return saveVersion(
			  objectName        = arguments.objectName
			, data              = arguments.data
			, versionNumber     = arguments.versionNumber
			, versionAuthor     = arguments.versionAuthor
			, manyToManyData    = arguments.manyToManyData
			, changedFields     = StructKeyArray( arguments.data )
		);
	}

	public numeric function saveVersionForUpdate(
		  required string  objectName
		, required string  id
		, required any     filter
		, required struct  filterParams
		, required struct  data
		, required struct  manyToManyData
		,          numeric versionNumber = getNextVersionNumber()
		,          string  versionAuthor = _getLoggedInUserId()
	) output=false {
		var poService              = _getPresideObjectService();
		var existingRecords        = poService.selectData( objectName = arguments.objectName, id=arguments.id, filter=arguments.filter, filterParams=arguments.filterParams );
		var newData                = Duplicate( arguments.data );

		StructDelete( newData, "datecreated" );
		StructDelete( newData, "datemodified" );

		for( var oldData in existingRecords ) {
			var changedFields = [];
			var dataChanged = false;
			var oldManyToManyData = poService.getDeNormalizedManyToManyData(
				  objectName       = arguments.objectName
				, id               = oldData.id
			);

			for( var field in newData ) {
				if ( StructKeyExists( oldData, field ) ) {
					var oldValue = IsNull( oldData[ field ] ) ? "" : oldData[ field ];
					var newValue = IsNull( newData[ field ] ) ? "" : newData[ field ];

				 	if ( oldValue != newValue ) {
						changedFields.append( field );
				 	}
				}
			}
			for( var field in arguments.manyToManyData ) {
				if ( StructKeyExists( oldManyToManyData, field ) && oldManyToManyData[ field ] != arguments.manyToManyData[ field ] ) {
					changedFields.append( field );
				}
			}
			dataChanged = changedFields.len();
			if ( !dataChanged ) {
				continue;
			}

			var mergedData  = Duplicate( oldData );
			var mergedManyToManyData = oldManyToManyData;

			StructDelete( mergedData, "datecreated" );
			StructDelete( mergedData, "datemodified" );
			StructAppend( mergedData, arguments.data );
			StructAppend( mergedManyToManyData, arguments.manyToManyData );

			saveVersion(
				  objectName     = arguments.objectName
				, data           = mergedData
				, versionNumber  = arguments.versionNumber
				, versionAuthor  = arguments.versionAuthor
				, manyToManyData = mergedManyToManyData
				, changedFields  = changedFields
			);
		}

		return arguments.versionNumber;
	}

	public numeric function saveVersion(
		  required string  objectName
		, required struct  data
		, required struct  manyToManyData
		, required array   changedFields
		,          numeric versionNumber = getNextVersionNumber()
		,          string  versionAuthor = _getLoggedInUserId()
	) output=false {
		var poService         = _getPresideObjectService();
		var versionObjectName = poService.getVersionObjectName( arguments.objectName );
		var versionedData     = Duplicate( arguments.data );
		var recordId          = versionedData.id ?: "";

		versionedData._version_number         = arguments.versionNumber;
		versionedData._version_author         = arguments.versionAuthor;
		versionedData._version_changed_fields = ',' & arguments.changedFields.toList() & ",";

		if ( poService.fieldExists( versionObjectName, "id" ) ) {
			versionedData.id = versionedData.id ?: NullValue();
		}

		poService.insertData(
			  objectName              = versionObjectName
			, data                    = versionedData
			, insertManyToManyRecords = false
			, useVersioning           = false
		);

		for( var propertyName in manyToManyData ){
			_saveManyToManyVersion(
				  sourceObjectName = arguments.objectName
				, sourceObjectId   = recordId
				, joinPropertyName = propertyName
				, values           = manyToManyData[ propertyName ]
				, versionNumber    = arguments.versionNumber
				, versionAuthor    = arguments.versionAuthor
			);
		}

		return arguments.versionNumber;
	}

// PRIVATE HELPERS
	private void function _removeUniqueIndexes( required struct objMeta ) output=false {
		for( var ixName in objMeta.indexes ) {
			var ix = objMeta.indexes[ ixName ];
			if ( IsBoolean( ix.unique ?: "" ) && ix.unique ) {
				StructDelete( objMeta.indexes, ixName );
			}
		}
	}

	private void function _removeRelationships( required struct objMeta ) output=false {
		objMeta.relationships = objMeta.relationships ?: {};

		StructClear( objMeta.relationships );
	}

	private void function _addAdditionalVersioningPropertiesToVersionObject( required struct objMeta, required string objectName ) output=false {
		if ( StructKeyExists( objMeta.properties, "id" ) ) {
			objMeta.properties.id.setAttribute( "pk", false );
			if ( objMeta.properties.id.getAttribute( "generator", "" ) == "increment" ) {
				throw( type="VersioningService.pkLimitiation", message="We currently cannot version objects with a an auto incrementing id.", detail="Please either use the default UUID generator for the id or turn versioning off on the object with versioned=false" );
			}
			objMeta.properties.id.setAttribute( "pk", false );
		}

		objMeta.properties[ "_version_number" ] = new Property(
			  name         = "_version_number"
			, required     = true
			, type         = "numeric"
			, dbtype       = "int"
			, indexes      = ""
			, control      = "none"
			, maxLength    = 0
			, relationship = "none"
			, relatedto    = "none"
			, generator    = "none"
		);

		objMeta.properties[ "_version_author" ] = new Property(
			  name         = "_version_author"
			, required     = false
			, type         = "string"
			, dbtype       = "varchar"
			, indexes      = ""
			, control      = "none"
			, maxLength    = 100
			, relationship = "none"
			, relatedto    = "none"
			, generator    = "none"
			, renderer     = "adminuser"
		);

		objMeta.properties[ "_version_changed_fields" ] = new Property(
			  name         = "_version_changed_fields"
			, required     = false
			, type         = "string"
			, dbtype       = "varchar"
			, indexes      = ""
			, control      = "none"
			, maxLength    = 800
			, relationship = "none"
			, relatedto    = "none"
			, generator    = "none"
		);

		objMeta.dbFieldList = ListAppend( objMeta.dbFieldList, "_version_number,_version_author,_version_changed_fields" );

		objMeta.indexes = objMeta.indexes ?: {};
		objMeta.indexes[ "ix_versioning_version_number" ] = { unique=false, fields="_version_number" };
		objMeta.indexes[ "ix_versioning_version_author" ] = { unique=false, fields="_version_author" };
		if ( StructKeyExists( objMeta.properties, "id" ) ) {
			objMeta.indexes[ "ix_versioning_record_id" ]      = { unique=false, fields="id,_version_number" };
		}
	}

	private any function _createVersionNumberSequenceObject( required string primaryDsn ) output=false {
		return { instance="auto_created", meta={
			  dbFieldList = "id,datecreated"
			, dsn         = primaryDsn
			, indexes     = {}
			, name        = "version_number_sequence"
			, tableName   = "_version_number_sequence"
			, tablePrefix = "_"
			, versioned   = false
			, properties  = {
				  id            = new Property( name="id"         , type="numeric", dbtype="int"      , control="none", maxLength=0, generator="increment", relationship="none", relatedTo="none", required=true, pk=true )
				, datecreated   = new Property( name="datecreated", type="date"   , dbtype="timestamp", control="none", maxLength=0, generator="none"     , relationship="none", relatedto="none", required=true )
			}
		} };
	}

	private void function _saveManyToManyVersion(
		  required string  sourceObjectName
		, required string  sourceObjectId
		, required string  joinPropertyName
		, required string  values
		, required numeric versionNumber
		, required string  versionAuthor
	) output=false {
		var poService      = _getPresideObjectService();
		var prop           = poService.getObjectProperty( arguments.sourceObjectName, arguments.joinPropertyName );
		var targetObject   = prop.relatedTo ?: "";
		var pivotTable     = prop.relatedVia ?: "";
		var versionedPivot = poService.getVersionObjectName( pivotTable );

		if ( Len( Trim( versionedPivot ) ) and Len( Trim( targetObject ) ) ) {
			transaction {
				var recordsToInsert = ListToArray( arguments.values );

				for( var targetId in recordsToInsert ) {
					poService.insertData(
						  objectName = versionedPivot
						, data       = {
							  "#arguments.sourceObjectName#" = arguments.sourceObjectId
							, "#targetObject#"               = targetId
							, _version_number                = arguments.versionNumber
							, _version_author                = arguments.versionAuthor
						}
					);
				}
			}
		}
	}

	private string function _getLoggedInUserId() output=false {
		var event = _getColdboxController().getRequestContext();

		return event.isAdminUser() ? event.getAdminUserId() : "";
	}

// GETTERS AND SETTERS
	private any function _getPresideObjectService() output=false {
		return _presideObjectService;
	}
	private void function _setPresideObjectService( required any presideObjectService ) output=false {
		_presideObjectService = arguments.presideObjectService;
	}

	private any function _getColdboxController() output=false {
		return _coldboxController;
	}
	private void function _setColdboxController( required any coldboxController ) output=false {
		_coldboxController = arguments.coldboxController;
	}
}