component extends="preside.system.base.AdminHandler" output=false {

	function index( event, rc, prc ) output=false {
		event.setLayout( "adminModalDialog" );
		event.setView( "admin/linkPicker/index" );
	}

}