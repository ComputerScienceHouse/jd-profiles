$(document).ready(function () {
	$("#search-field").keydown(function (e) {
		if(e.keycode == 13) {
			$.ajax({
			  url: "/results",
			  method: "POST",
			  data: {
			  	"query": $("#search-field").val()
			  }
			}).done(function() {
			  $( this ).addClass( "done" );
			});
		}
	})
});