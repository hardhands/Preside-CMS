/**
 * Our own little tree widget for navigation site tree / asset manager
 *
 */

( function( $ ){

	var PresideTreeNav = ( function() {
		function PresideTreeNav( $tree, options ) {
			this.$tree = $tree;

			this.setupOptions( options );
			this.setupUxBehaviours();
			this.initializeSelection();
		};

		PresideTreeNav.prototype.setupOptions = function( userProvidedOptions ){
			var defaultOptions = {};

			this.options = $.extend( {}, defaultOptions, userProvidedOptions );
		};

		PresideTreeNav.prototype.setupUxBehaviours = function(){
			var treeNav = this;

			treeNav.$tree.on( "click", ".tree-node-toggler", function( e ){
				treeNav.toggleNode( $( this ).closest( ".tree-folder" ) );
			} );

			if ( typeof treeNav.options.onClick === "function" ) {
				treeNav.$tree.on( "click", ".tree-node", function( e ){
					var $node = $( this );

					treeNav.options.onClick( $node );
				} );

				treeNav.$tree.on( "keydown", ".tree-node", "return", function( e ){
					var $node = $( this );

					treeNav.options.onClick( $node );

					e.stopPropagation();
				} );
			}

			treeNav.$tree.on( "keydown", ".tree-folder-header", "left", function( e ){
				e.stopPropagation();
				treeNav.toggleNode( $( this ).parent(), false );
			} );

			treeNav.$tree.on( "keydown", ".tree-folder-header", "right", function( e ){
				e.stopPropagation();
				treeNav.toggleNode( $( this ).parent(), true );
			} );
		};

		PresideTreeNav.prototype.toggleNode = function( $node, show ){
			var $header        = $node.find( ".tree-folder-header:first" )
			  , $nodeChildren  = $node.find( ".tree-folder-content:first" )
			  , $plusMinusIcon = $header.find( "i:first" );

			if ( typeof show === "undefined" ) {
				$nodeChildren.toggleClass( "open" );
				$plusMinusIcon.toggleClass( "fa-plus" );
				$plusMinusIcon.toggleClass( "fa-minus" );
			} else {
				$nodeChildren.toggleClass( "open", show );
				$plusMinusIcon.toggleClass( "fa-plus", !show );
				$plusMinusIcon.toggleClass( "fa-minus", show );
			}
		};

		PresideTreeNav.prototype.initializeSelection = function(){
			var $selectedNode = this.$tree.find( ".selected" )
			  , treeNav       = this;

			if ( $selectedNode.length ) {
				$selectedNode.parents( ".tree-folder" ).each( function(){
					treeNav.toggleNode( $( this ), true );
				} );

				$selectedNode.focus();
			} else {
				treeNav.toggleNode( this.$tree.find( ".tree-folder" ).first(), true );
			}
		};

		return PresideTreeNav;
	} )();


	$.fn.presideTreeNav = function( options ) {
		return this.each( function() {
			var $this          = $( this )
			  , presideTreeNav = $this.data( 'presideTreeNav' );

			if ( !presideTreeNav ) {
				$this.data( 'presideTreeNav', new PresideTreeNav( $this, options ) );
			}
		} );
	};

} )( presideJQuery );