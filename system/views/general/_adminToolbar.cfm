<cfif event.isAdminUser()>
	<cfscript>
		event.include( "/js/admin/presidecore/" );
		event.include( "/js/admin/frontend/" );
		event.include( "i18n-resource-bundle" );
		event.include( "/css/admin/core/" );
		event.include( "/css/admin/frontend/" );
		event.includeData({
			  ajaxEndpoint = event.buildAdminLink( linkTo="ajaxProxy.index" )
			, adminBaseUrl = event.getAdminPath()
		});

		toolbarUrl = event.buildAdminLink(
			  linkTo      = 'general.adminToolbar'
			, querystring = 'pageId=#event.getCurrentPageId()#&template=#event.getCurrentTemplate()#'
		);

		if ( hasPermission( "devtools.console" ) ) {
			event.include( "/js/admin/devtools/" );
			event.include( "/css/admin/devtools/" );
		}

		ckEditorJs = renderView( "admin/layout/ckeditorjs" );
	</cfscript>

	<cfoutput>
		<div class="preside-admin-toolbar presidecms" id="preside-admin-toolbar">
			<a href="#event.buildAdminLink()#"><h1>#translateResource( "cms:admintoolbar.title" )#</h1></a>

			<ul class="preside-admin-toolbar-actions list-unstyled">
				<li>
					<div class="edit-mode-toggle-container">
						<label>
							#translateResource( "cms:admintoolbar.editmode" )#
							<input id="edit-mode-options" class="ace ace-switch ace-switch-6" type="checkbox" />
							<span class="lbl"></span>
						</span>
					</div>
					<a class="view-in-tree-link" href="#event.buildAdminLink( linkTo='sitetree', queryString='selected=#event.getCurrentPageId()#' )#" title="#translateResource( 'cms:admintoolbar.view.in.tree' )#">
						<i class="fa fa-sitemap"></i>
					</a>
				</li>
				<li>
					<a href="#event.buildAdminLink( linkTo="login.logout", querystring="redirect=referer" )#">
						<img class="nav-user-photo" src="http://www.gravatar.com/avatar/#LCase( Hash( LCase( event.getAdminUserDetails().emailAddress ) ) )#?r=g&d=mm&s=40" alt="Avatar for #HtmlEditFormat( event.getAdminUserDetails().knownAs )#" />
						<span class="logout-link"> #translateResource( "cms:logout.link" )# </span>
					</a>
				</li>
			</ul>
		</div>

		#ckEditorJs#
	</cfoutput>
</cfif>

