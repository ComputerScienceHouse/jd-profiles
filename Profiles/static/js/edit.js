$(function() {
	$("#edit").on('click', function (e) {
		$.get("/edit").done( function(result){
		    $('body').html(result);
		});
	});
});

$(function() {
	$("#save").on('click', function (e) {

		var name = $("#name-field").val();
		var birthday = $("#birthday-field").val();
		var phone = $("#phone-field").val();
		var plex = $("#plex-field").val();
		var major = $("#major-field").val();
		var ritYear = $("#ritYear-field").val();
		var ritAlumni = $("#alumni-field").val();
		var website = $("#website-field").val();
		var github = $("#github-field").val();
		var twitter = $("#twitter-field").val();
		var blog = $("#blog-field").val();
		var google = $("#google-field").val();

		$.ajax({
			url: '/update',
			data: {
				"name": name,
				"birthday": birthday,
				"phone": phone,
				"plex": plex,
				"major": major,
				"ritYear": ritYear,
				"website": website,
				"github": github,
				"twitter": twitter,
				"blog": blog,
				"google": google
			},
			method: 'POST',
			success: function (data, textStatus, jqXHR) {
				location.reload();
			},
			error: function(error) {
				console.log(error);
			}
		});
	});
});

$(function() {
	$("#photo-button").on('click', function (e) {


			var photo = $("#photo").val();
			$.ajax({
				url: '/update',
				data: {
					"photo": photo
				},
				method: 'POST',
				success: function (data, textStatus, jqXHR) {
				      
				},
				error: function(error) {
					console.log(error);
				}
			});
		
	});
});
