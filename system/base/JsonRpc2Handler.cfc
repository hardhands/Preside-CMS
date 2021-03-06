component output=false hint="I am a base handler for any handlers implementing JSON-RPC 2.0" {

	property name="jsonRpc2Plugin" inject="coldbox:myPlugin:JsonRpc2";

	function aroundIndex( event, targetAction, eventArguments ) output=false {
		event.noLayout();

		if ( !jsonRpc2Plugin.readRequest() ) {
			return;
		};

		if ( !hasPermission( "devtools.console" ) ) {
			jsonRpc2Plugin.error( 401, "You do not have permission to access the console" );
			return;
		}

		var args = {
			  event = arguments.event
			, rc    = arguments.event.getCollection()
			, prc   = arguments.event.getCollection( private=true )
		};
		StructAppend( args, eventArguments );

		try {
			var result = arguments.targetAction( argumentCollection = args );
			if ( not IsNull( result ) ) {
				jsonRpc2Plugin.success( result );
			}
		} catch ( any e ) {
			jsonRpc2Plugin.error( 500, "A processing error occurred", { message=e.message, detail=e.detail } );
			return;
		}
	}
}