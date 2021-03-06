<cfscript>
	prc.pageIcon  = "picture-o";
	prc.pageTitle = translateResource( "cms:assetManager" );

	folder      = rc.folder ?: "";
	folderTitle = prc.folder.label ?: translateResource( "cms:assetmanager.root.folder" );
	folderTree  = prc.folderTree ?: [];
</cfscript>

<cfoutput>
	<div id="browse" class="row">
		<div class="col-sm-5 col-md-4 col-lg-3">
			<div class="navigation-tree-container">
				<div class="preside-tree-nav tree tree-unselectable" data-nav-list="1" data-nav-list-child-selector=".tree-folder-header,.tree-item">
					<cfloop array="#folderTree#" index="node">
						#renderView( view="/admin/assetmanager/_treeFolderNode", args=node )#
					</cfloop>
				</div>
			</div>
		</div>
		<div class="col-sm-7 col-md-8 col-lg-9">
			<div class="title-and-actions-container clearfix">
				#renderView( view="admin/assetmanager/_folderTitleAndActions", args={ folderId=folder, folderTitle=folderTitle } )#
			</div>
			#renderView( "admin/assetmanager/listingtable" )#
		</div>
	</div>
</cfoutput>

