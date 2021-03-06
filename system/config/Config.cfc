component output=false {

	public void function configure() output=false {
		coldbox = {
			  appName                   = "OpenPreside Website"
			, handlersIndexAutoReload   = false
			, debugMode                 = false
			, defaultEvent              = "general.index"
			, customErrorTemplate       = ""
			, reinitPassword            = "true"
			, handlerCaching            = true
			, eventCaching              = true
			, requestContextDecorator   = "preside.system.coldboxModifications.RequestContextDecorator"
			, UDFLibraryFile            = _getUdfFiles()
			, pluginsExternalLocation   = "preside.system.plugins"
			, viewsExternalLocation     = "/preside/system/views"
			, layoutsExternalLocation   = "/preside/system/layouts"
			, modulesExternalLocation   = ["/preside/system/modules"]
			, handlersExternalLocation  = "preside.system.handlers"
			, applicationStartHandler   = "General.applicationStart"
			, requestStartHandler       = "General.requestStart"
			, missingTemplateHandler    = "General.notFound"
			, onInvalidEvent            = "General.notFound"
			, coldboxExtensionsLocation = "preside.system.coldboxModifications"
		};

		i18n = {
			  defaultLocale      = "en"
			, localeStorage      = "cookie"
			, unknownTranslation = "**NOT FOUND**"
		};

		interceptors = [
			{ class="preside.system.interceptors.CsrfProtectionInterceptor", properties={} },
			{ class="preside.system.interceptors.SES"                      , properties = { configFile = "/preside/system/config/Routes.cfm" } }
		];
		interceptorSettings = {
			  throwOnInvalidStates     = false
			, customInterceptionPoints = "onBuildLink"
		};

		cacheBox = {
			configFile = "preside.system.config.Cachebox"
		};

		wirebox = {
			  singletonReload = false
			, binder          = _discoverWireboxBinder()
		};

		settings = {};
		settings.eventName                 = "event";
		settings.formControls              = {};
		settings.widgets                   = {};
		settings.templates                 = [];
		settings.adminDefaultEvent         = "sitetree";
		settings.preside_admin_path        = "admin";
		settings.presideHelpAndSupportLink = "http://www.pixl8.co.uk";
		settings.dsn                       = "preside";
		settings.presideObjectsTablePrefix = "pobj_";
		settings.system_users              = "sysadmin";
		settings.updateRepositoryUrl       = "http://downloads.presidecms.com.s3.amazonaws.com";
		settings.notFoundLayout            = "Main";
		settings.notFoundViewlet           = "errors.notFound";
		settings.serverErrorLayout         = "Main";
		settings.serverErrorViewlet        = "errors.serverError";

		settings.assetManager = {
			  maxFileSize       = "5"
			, types             = _getConfiguredFileTypes()
			, derivatives       = _getConfiguredAssetDerivatives()
		};
		settings.assetManager.allowedExtensions = _typesToExtensions( settings.assetManager.types );

		settings.activeExtensions = _loadExtensions();

		settings.permissions = {
			  cms                 = [ "login" ]
			, sitetree            = [ "navigate", "read", "add", "edit", "delete", "manageContextPerms", "viewversions" ]
			, sites               = [ "navigate", "manage" ]
			, datamanager         = [ "navigate", "read", "add", "edit", "delete", "manageContextPerms", "viewversions" ]
			, usermanager         = [ "navigate", "read", "add", "edit", "delete" ]
			, groupmanager        = [ "navigate", "read", "add", "edit", "delete" ]
			, devtools            = [ "console" ]
			, systemConfiguration = [ "manage" ]
			, presideobject       = {
				  security_user  = [ "read", "add", "edit", "delete", "viewversions" ]
				, security_group = [ "read", "add", "edit", "delete", "viewversions" ]
				, page           = [ "read", "add", "edit", "delete", "viewversions" ]
				, site           = [ "read", "add", "edit", "delete", "viewversions" ]
				, asset          = [ "read", "add", "edit", "delete", "viewversions" ]
				, asset_folder   = [ "read", "add", "edit", "delete", "viewversions" ]
			}
			, assetmanager        = {
				  general = [ "navigate" ]
				, folders = [ "add", "edit", "delete", "manageContextPerms" ]
				, assets  = [ "upload", "edit", "delete", "download", "pick" ]
			 }
		};

		settings.roles = StructNew( "linked" );

		settings.roles.user           = [ "cms.login" ];
		settings.roles.sysadmin       = [ "usermanager.*", "groupmanager.*", "systemConfiguration.*", "presideobject.security_user.*", "presideobject.security_group.*" ];
		settings.roles.siteManager    = [ "sites.*", "presideobject.site.*" ];
		settings.roles.siteUser       = [ "sites.navigate", "presideobject.site.read" ];
		settings.roles.sitetreeAdmin  = [ "sitetree.*", "presideobject.page.*" ];
		settings.roles.sitetreeEditor = [ "sitetree.navigate", "sitetree.read", "sitetree.edit", "sitetree.add", "presideobject.page.*" ];
		settings.roles.dataAdmin      = [ "datamanager.*" ];
		settings.roles.assetAdmin     = [ "assetmanager.*", "presideobject.asset.*", "presideobject.asset_folder.*" ];
		settings.roles.assetEditor    = [ "assetmanager.*", "!assetmanager.*.manageContextPerms", "!assetmanager.*.delete", "presideobject.asset.*", "presideobject.asset_folder.*" ];

		// uploads directory - each site really should override this setting and provide an external location
		settings.uploads_directory     = ExpandPath( "/uploads" );
		settings.tmp_uploads_directory = ExpandPath( "/uploads" );

		settings.ckeditor = {
			  defaults    = {
				  stylesheets = [ "/css/admin/specific/richeditor/" ]
				, width       = "auto"
				, minHeight   = 0
				, maxHeight   = 600
				, configFile  = "/ckeditorExtensions/config.js"
			  }
			, toolbars    = _getCkEditorToolbarConfig()
		};

		settings.static = {
			  rootUrl        = ""
			, siteAssetsPath = "/assets"
			, siteAssetsUrl  = "/assets"
		};

		environments = {
            local = "^local\.,\.local$,^localhost$,^127.0.0.1$"
        }

	}

// ENVIRONMENT SPECIFIC
	public void function local() output=false {
		settings.showErrors = true;
	}

// PRIVATE UTILITY
	private array function _getUdfFiles() output=false {
		var udfs     = DirectoryList( "/preside/system/helpers", true, false, "*.cfm" );
		var siteUdfs = ArrayNew(1);
		var udf      = "";
		var i        = 0;

		for( i=1; i lte ArrayLen( udfs ); i++ ) {
			udfs[i] = _getMappedPathFromFull( udfs[i], "/preside/system/helpers/" );
		}

		if ( DirectoryExists( "/helpers" ) ) {
			siteUdfs = DirectoryList( "/helpers", true, false, "*.cfm" );

			for( udf in siteUdfs ){
				ArrayAppend( udfs, _getMappedPathFromFull( udf, "/helpers" ) );
			}
		}

		return udfs;
	}

	private string function _getMappedPathFromFull( required string fullPath, required string mapping ) output=false {
		var expandedMapping       = ExpandPath( arguments.mapping );
		var pathRelativeToMapping = Replace( arguments.fullPath, expandedMapping, "" );

		return arguments.mapping & Replace( pathRelativeToMapping, "\", "/", "all" );
	}

	private string function _discoverWireboxBinder() output=false {
		if ( FileExists( "/app/config/WireBox.cfc" ) ) {
			return "app.config.WireBox";
		}

		return 'preside.system.config.WireBox';
	}

	private array function _loadExtensions() output=false {
		return new preside.system.services.devtools.ExtensionManagerService( "/app/extensions" ).listExtensions( activeOnly=true );
	}

	private struct function _getConfiguredFileTypes() output=false{
		var types = {};

		types.image = {
			  jpg  = { serveAsAttachment=false, mimeType="image/jpg"  }
			, jpeg = { serveAsAttachment=false, mimeType="image/jpeg" }
			, gif  = { serveAsAttachment=false, mimeType="image/gif"  }
			, png  = { serveAsAttachment=false, mimeType="image/png"  }
		};

		types.document = {
			  pdf  = { serveAsAttachment=true, mimeType="application/pdf"  }
			, doc  = { serveAsAttachment=true, mimeType="application/msword" }
			, dot  = { serveAsAttachment=true, mimeType="application/msword" }
			, docx = { serveAsAttachment=true, mimeType="application/vnd.openxmlformats-officedocument.wordprocessingml.document" }
			, dotx = { serveAsAttachment=true, mimeType="application/vnd.openxmlformats-officedocument.wordprocessingml.template" }
			, docm = { serveAsAttachment=true, mimeType="application/vnd.ms-word.document.macroEnabled.12" }
			, dotm = { serveAsAttachment=true, mimeType="application/vnd.ms-word.template.macroEnabled.12" }
			, xls  = { serveAsAttachment=true, mimeType="application/vnd.ms-excel" }
			, xlt  = { serveAsAttachment=true, mimeType="application/vnd.ms-excel" }
			, xla  = { serveAsAttachment=true, mimeType="application/vnd.ms-excel" }
			, xlsx = { serveAsAttachment=true, mimeType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }
			, xltx = { serveAsAttachment=true, mimeType="application/vnd.openxmlformats-officedocument.spreadsheetml.template" }
			, xlsm = { serveAsAttachment=true, mimeType="application/vnd.ms-excel.sheet.macroEnabled.12" }
			, xltm = { serveAsAttachment=true, mimeType="application/vnd.ms-excel.template.macroEnabled.12" }
			, xlam = { serveAsAttachment=true, mimeType="application/vnd.ms-excel.addin.macroEnabled.12" }
			, xlsb = { serveAsAttachment=true, mimeType="application/vnd.ms-excel.sheet.binary.macroEnabled.12" }
			, ppt  = { serveAsAttachment=true, mimeType="application/vnd.ms-powerpoint" }
			, pot  = { serveAsAttachment=true, mimeType="application/vnd.ms-powerpoint" }
			, pps  = { serveAsAttachment=true, mimeType="application/vnd.ms-powerpoint" }
			, ppa  = { serveAsAttachment=true, mimeType="application/vnd.ms-powerpoint" }
			, pptx = { serveAsAttachment=true, mimeType="application/vnd.openxmlformats-officedocument.presentationml.presentation" }
			, potx = { serveAsAttachment=true, mimeType="application/vnd.openxmlformats-officedocument.presentationml.template" }
			, ppsx = { serveAsAttachment=true, mimeType="application/vnd.openxmlformats-officedocument.presentationml.slideshow" }
			, ppam = { serveAsAttachment=true, mimeType="application/vnd.ms-powerpoint.addin.macroEnabled.12" }
			, pptm = { serveAsAttachment=true, mimeType="application/vnd.ms-powerpoint.presentation.macroEnabled.12" }
			, potm = { serveAsAttachment=true, mimeType="application/vnd.ms-powerpoint.template.macroEnabled.12" }
			, ppsm = { serveAsAttachment=true, mimeType="application/vnd.ms-powerpoint.slideshow.macroEnabled.12" }
		}

		// TODO, more types to be defined here!

		return types;
	}

	private string function _typesToExtensions( required struct types ) output=false {
		var extensions = [];
		for( var cat in arguments.types ) {
			for( var ext in arguments.types[ cat ] ) {
				extensions.append( "." & ext );
			}
		}

		return extensions.toList();
	}

	private struct function _getConfiguredAssetDerivatives() output=false {
		var derivatives  = {};

		derivatives.adminthumbnail = {
			  permissions = "inherit"
			, transformations = [
				  { method="pdfPreview" , args={ page=1                }, inputfiletype="pdf", outputfiletype="jpg" }
				, { method="shrinkToFit", args={ width=200, height=200 } }
			  ]
		};

		derivatives.icon = {
			  permissions = "inherit"
			, transformations = [ { method="shrinkToFit", args={ width=32, height=32 } } ]
		};

		derivatives.pickericon = {
			  permissions = "inherit"
			, transformations = [ { method="shrinkToFit", args={ width=48, height=32 } } ]
		};

		return derivatives;
	}

	private struct function _getCkEditorToolbarConfig() output=false {
		return {
			full     =  'Maximize,-,Source,-,Preview'
					 & '|Cut,Copy,Paste,PasteText,PasteFromWord,-,Undo,Redo'
					 & '|Find,Replace,-,SelectAll,-,Scayt'
					 & '|Widgets,ImagePicker,AttachmentPicker,Table,HorizontalRule,SpecialChar,Iframe'
					 & '|PresideLink,PresideUnlink,PresideAnchor'
					 & '|Bold,Italic,Underline,Strike,Subscript,Superscript'
					 & '|NumberedList,BulletedList,-,Outdent,Indent,-,Blockquote,CreateDiv,-,JustifyLeft,JustifyCenter,JustifyRight,JustifyBlock,-,BidiLtr,BidiRtl,Language'
					 & '|Styles,Format',

			noInserts = 'Maximize,-,Source,-,Preview'
					 & '|Cut,Copy,Paste,PasteText,PasteFromWord,-,Undo,Redo'
					 & '|Find,Replace,-,SelectAll,-,Scayt'
					 & '|PresideLink,PresideUnlink,PresideAnchor'
					 & '|Bold,Italic,Underline,Strike,Subscript,Superscript'
					 & '|NumberedList,BulletedList,-,Outdent,Indent,-,Blockquote,CreateDiv,-,JustifyLeft,JustifyCenter,JustifyRight,JustifyBlock,-,BidiLtr,BidiRtl,Language'
					 & '|Styles,Format',

			bolditaliconly = 'Bold,Italic'
		};

	}
}