( function( $ ){

	var $container      = $( '.add-asset-forms:first' )
	  , $forms          = $container.find( 'form.add-asset-form' )
	  , $activeFormNum  = $container.find( '.asset-number:first' )
	  , savedAssets     = []
	  , activeFormIndex = 0
	  , getActiveForm, setActiveForm, processActiveForm, isComplete, getUploaded, nextStep, setDefaultFormValuesForSubsequentForms, checkLastStep;

	getActiveForm = function(){
		return $forms.filter( ".active" ).first();
	};

	setActiveForm = function( ix ){
		var $activeForm = $( $forms.get( ix ) );

		$forms.removeClass( "active" );
		$activeFormNum.html( ix+1 );

		$activeForm.addClass( "active" );
		$activeForm.find( "input,select,textarea" ).not( ":hidden" ).first().focus();

		checkLastStep();
	};

	processActiveForm = function( callback ){
		var $form = getActiveForm();

		if ( $form.valid() ) {
			$.ajax({
				  type    : "POST"
				, url     : $form.attr( 'action' )
				, data    : $form.serializeObject()
				, success : function( data ) { callback( data ); }
				, error   : function() { callback( { success : false } ); }
			});
		}
	};

	isComplete = function(){
		return savedAssets.length === $forms.length;
	};

	getUploaded = function(){
		return savedAssets;
	};

	nextStep = function(){
		if ( !isComplete() ) {
			processActiveForm( function( data ){
				if ( data.success ) {
					savedAssets.push( data.id );

					if ( activeFormIndex+1 < $forms.length ) {
						setDefaultFormValuesForSubsequentForms();

						getActiveForm().fadeOut( 100, function(){
							$( $forms.get( activeFormIndex+1 ) ).fadeIn( 100, function(){
								setActiveForm( ++activeFormIndex );
							} );
						} );
					} else {
						uberAssetSelect.uploadStepsFinished();
					}
				} else if ( typeof data.validationResult === "object" ) {
					getActiveForm().validate().showErrors( data.validationResult );
				}
			} );
		}
	};

	setDefaultFormValuesForSubsequentForms = function(){
		var currentFormValues = getActiveForm().serializeObject()
		  , excludeFields     = /label|description|fileid/i
		  , key, i, $field;


		for( key in currentFormValues ){
			if ( !excludeFields.test( key ) ) {
				for( i=activeFormIndex; i<$forms.length; i++ ){
					$field = $( $forms.get( i ) ).find( '[name="' + key + '"]' ).first();

					if ( $field.length ) {
						if ( typeof $field.data( 'uberSelect' ) !== "undefined" ) {
							$field.data( 'uberSelect' ).select( currentFormValues[ key ] );
						} else {
							$field.val( currentFormValues[ key ] );
						}
					}
				}
			}
		}
	};

	checkLastStep = function(){
		if ( typeof uberAssetSelect !== "undefined" && activeFormIndex === $forms.length-1 ){
			uberAssetSelect.enteredLastStep();
		}
	};

	setActiveForm( activeFormIndex );
	$forms.find( "input,select,textarea" ).keydown( "ctrl+return", function( e ){
		e.preventDefault();
		nextStep();
	} );

	window.assetUploader = {
		  getUploaded   : getUploaded
		, nextStep      : nextStep
		, checkLastStep : checkLastStep
	};
} )( presideJQuery );