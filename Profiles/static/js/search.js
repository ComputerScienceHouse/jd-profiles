$(function() {
	$("#search-field").keydown(function (e) {
		if(e.keycode == 13) {
			$.ajax({
				url: '/results',
				data: {
					"query": $("#search-field").val()
				},
				type: 'POST',
				success: function(response) {
					console.log(response);
				},
				error: function(error) {
					console.log(error);
				}
			});
		}
	});
});