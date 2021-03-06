<cfscript>
	inputName    = args.name         ?: "";
	inputId      = args.id           ?: "";
	placeholder  = args.placeholder  ?: "";
	defaultValue = args.defaultValue ?: "";
	maxLength    = Val( args.maxLength ?: 0 );

	value  = event.getValue( name=inputName, defaultValue=defaultValue );
	if ( not IsSimpleValue( value ) ) {
		value = "";
	}
</cfscript>

<cfoutput>
	<textarea id="#inputId#" placeholder="#placeholder#" name="#inputName#" class="form-control autosize-transition<cfif maxLength> limited</cfif>"<cfif maxLength> data-maxlength="#maxLength#"</cfif> tabindex="#getNextTabIndex()#">#value#</textarea>
</cfoutput>