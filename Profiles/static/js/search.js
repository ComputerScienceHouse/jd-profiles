$(function() {
	$("#search-field").keypress(function (e) {
		console.log(e.which);
		if(e.which == 13 || e.which == 10) {
			$.ajax({
				url: '/results',
				data: {
					"query": $("#search-field").val()
				},
				method: 'POST',
				success: function (data, textStatus, jqXHR) {
				      $("body").html(data);
				},
				error: function(error) {
					console.log(error);
				}
			});
		}
	});
});
