component output=false {

	property name="presideObjectService" inject="presideObjectService";
	property name="dataManagerService" inject="dataManagerService";

	public string function index( event, rc, prc, args={} ) output=false {
		var targetObject = args.object ?: "";
		var ajax         = args.ajax   ?: true;

		if ( IsBoolean( ajax ) && ajax ) {
			if ( not StructKeyExists( args, "prefetchUrl" ) ) {
				var prefetchCacheBuster = dataManagerService.getPrefetchCachebusterForAjaxSelect( targetObject );

				args.prefetchUrl = event.buildAdminLink( linkTo="datamanager.getObjectRecordsForAjaxSelectControl", querystring="object=#targetObject#&prefetchCacheBuster=#prefetchCacheBuster#" );
			}
			args.remoteUrl = args.remoteUrl ?: event.buildAdminLink( linkTo="datamanager.getObjectRecordsForAjaxSelectControl", querystring="object=#targetObject#&q=%QUERY" );
		} else {
			args.records = presideObjectService.selectData(
				  objectName   = targetObject
				, selectFields = [ "#targetObject#.id", "${labelfield} as label" ]
				, orderBy      = "label"
			);
		}

		if ( !Len( Trim( args.placeholder ?: "" ) ) ) {
			args.placeholder = translateResource(
				  uri  = "cms:datamanager.search.data.placeholder"
				, data = [ translateResource( uri=presideObjectService.getResourceBundleUriRoot( targetObject ) & "title", defaultValue=translateResource( "cms:datamanager.records" ) ) ]
			);
		}

		return renderView( view="formcontrols/objectPicker/index", args=args );
	}
}