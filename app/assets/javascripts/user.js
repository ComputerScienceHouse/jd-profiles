var hidden = true;

/*
 * Creates the input field for the given attribute parameters
 * id: the id of the div to add the input field to
 * val: the default value to give it
 */
function create_input(id, val, hidden) {
    var attr_id = id.slice(15, id.length);  // ex: cn-0
    var attr = attr_id.split('-')[0];       // ex: cn
    var input_id = "attr-input-" + attr_id; // ex: attr-input-cn-0
    
    $("#" + input_id).remove();
    $('#' + id).append('<input class="form-control" id="' + input_id + '" name="' + attr_id + '" type="text" value="' + $.trim(val)  + '">');
    $('#' + input_id).keypress(function(event) {
        if (event.which == 13) {
            event.preventDefault();
            $('#attr-form-' + attr).submit();
        }
    });

    if (hidden) {
        $("#" + input_id).css('display', 'none');
    }
}

/*
 * Flashes the success status to the user. It makes the inputs' border color
 * green if it successfully updated, red otherwise
 * id: the id of the inputs to modify
 * success: if the updats was successful
 */
function flash_success(id, success, error) {
    var org_border_color = $(id).css('border-color');
    var org_border_width = $(id).css('border-width');
    var border_color = success ? 'rgb(35, 230, 35)' : 'red';

    $(id).css('border-color', border_color);
    $(id).css('border-width', '5px');

    if (!success) {
        var error_class = Math.random().toString(36).substring(7);
        console.log(id);
        console.log(error);

        $(id).after('<small class="' + error_class + ' error">' + error + '</small>');
        setTimeout(function() {
            $('.' + error_class).remove();        
        }, 1000);
    }

    setTimeout(function() { 
        $(id).css('border-color', org_border_color); 
        $(id).css('border-width', org_border_width); 
    }, 1000);
}


$(document).on('page:change', function () {
    $('#image-thumb').click(function() {
        if ($("#image-form").css("display") == "none") {
            $("#image-form").css("display", "inherit");    
        } else {
            $("#image-form").css("display", "none");    
        }
    });

    $("#ibutton-toggle").click(function() {
        if ($("#attr-form-ibutton").is(":visible")) {
            $("#ibutton-toggle").text("View iButtons")    
        } else {
            $("#ibutton-toggle").text("Hide iButtons")    
        }
        $("#attr-form-ibutton").toggle();
    });
    $("#attr-form-ibutton").hide();

    $('.attr-form').bind('ajax:success', function(evt, data, xhr) {
        var response = $.parseJSON(status);
        var attr_id = response.key;
        if (!hidden) {
            if (response.single) {
                $('#attr-input-' + attr_id).val(response.value[0]);
                $('#attr-' + attr_id).text(response.value[0]);
                flash_success('#attr-input-' + attr_id, response.success, response.error);
            } else {
                if (!response.success) {
                    $("input[id^='attr-input-" + attr_id + "']").remove();
                    $("div[id^='attr-input-div-" + attr_id + "']").each(function(index) {
                        var id = $(this).attr('id'); // ex: attr-input-div-cn-0
                        var val = (index < response.value.length) ? response.value[index] : "";    
                        create_input(id,  val, false);    
                        });
                    flash_success("input[id^='attr-input-" + attr_id + "']", false, response.error);
                } else {
                    $("div[id^='attr-input-div-" + attr_id + "']").remove();
                    var i = 0;
                    for (i = 0 ; i < response.value.length ; i++) {
                        var id = "attr-input-div-" + attr_id + "-" + i;
                        $("#attr-form-" + attr_id).append('<div id="' + id + '" class="attr-input-div"></div>');
                        create_input(id,  response.value[i], false);
                        // updates the read-only versions and adds new read-only divs if needed
                        if ($("#attr-" + attr_id + "-" + i).length) {
                            $("#attr-" + attr_id + "-" + i).text(response.value[i]);
                        } else {
                            $("#attr-form-" + attr_id).append('<div id="attr-' + attr_id + 
                                    '-' + i + '" class="attr" style="display: none;"></div>');
                            $("#attr-" + attr_id + "-" + i).text(response.value[i]);
                             
                        }
                    }
                    // removes any extra values that were just deleted
                    while ($("#attr-" + attr_id + "-" + i).length) {
                        $("#attr-" + attr_id + "-" + i).remove(); 
                    }
                    var id = "attr-input-div-" + attr_id + "-" + response.value.length;
                    $("#attr-form-" + attr_id).append('<div id="' + id + '" class="attr-input-div"></div>');
                    create_input(id, "", false);    
                    flash_success("input[id^='attr-input-" + attr_id + "']", true);
                } 
            }
        } else {  // hidden
            if (response.single) {
                $('#attr-input-' + attr_id).val(response.value[0]);
                if (response.value.length == 0) {
                    $('#attr-' + attr_id).text("");
                } else {
                    $('#attr-' + attr_id).text(response.value[0]);
                }
            } else {
                if (!response.success) {
                    $("input[id^='attr-input-" + attr_id + "']").remove();
                    $("div[id^='attr-input-div-" + attr_id + "']").each(function(index) {
                        var id = $(this).attr('id'); // ex: attr-input-div-cn-0
                        var val = (index < response.value.length) ? response.value[index] : "";    
                        create_input(id,  val, true);    
                        $('#attr-' + attr_id).text(response.value[0]);
                        });
                } else {
                    $("div[id^='attr-input-div-" + attr_id + "']").remove();
                    var i = 0;
                    for (i = 0 ; i < response.value.length ; i++) {
                        var id = "attr-input-div-" + attr_id + "-" + i;
                        $("#attr-form-" + attr_id).append('<div id="' + id + '" class="attr-input-div"></div>');
                        create_input(id,  response.value[i], true);

                        // updates the read-only versions and adds new read-only divs if needed
                        if ($("#attr-" + attr_id + "-" + i).length) {
                            $("#attr-" + attr_id + "-" + i).text(response.value[i]);
                        } else {
                            $("#attr-form-" + attr_id).append('<div id="attr-' + attr_id + 
                                    '-' + i + '" class="attr"></div>');
                            $("#attr-" + attr_id + "-" + i).text(response.value[i]);          
                        }
                    }
                    // removes any extra values that were just deleted
                    while ($("#attr-" + attr_id + "-" + i).length) {
                        $("#attr-" + attr_id + "-" + i).remove(); 
                    }
                    var id = "attr-input-div-" + attr_id + "-" + response.value.length;
                    $("#attr-form-" + attr_id).append('<div id="' + id + '" class="attr-input-div"></div>');
                    create_input(id, "", true);    
                } 
            }
        }
    });
    
    var cache = {};
    $("#search_search").autocomplete({
        minLength: 2,
        source: function( request, response ) {
            var term = request.term;
            if ( term in cache ) {
                response( cache[ term ] );
                return;
            }
            $.getJSON( "/autocomplete", request, function( data, status, xhr ) {
                cache[ term ] = data;
                response( data );
            });
        },
        select: function( event, ui ) {
            $('#search_form').submit();  // This submits the form
        }
     });


    $("#edit-button").click(function(e) {
        if ($(this).text() == "edit") {
            hidden = false;
            $(this).text("done");
            $('.attr-form').css('display', 'inherit'); // unhides empty fields
            $('.attr').hide();                         // hides all the current info
            $('.attr-input-div').each(function(index) {
                var id = $(this).attr('id');           // ex: attr-input-div-cn-0
                var attr_id = id.slice(15, id.length); // ex: cn-0
                var val = $('#attr-' + attr_id).text();
                create_input(id, val);    
            });
        } else {
            hidden = true;
            console.log($("#attr-input-cn-1").val());
            /* hides all empty forms */
            $('.attr-form').each(function(index) {
                var is_empty = true;
                $(this).find('input').each(function(index) {
                    if (index != 0 && $(this).val().length != 0) {
                        is_empty = false;
                        return false;
                    }
                });
                if (is_empty) {
                    $(this).css('display', 'none');
                }
            });
            $('[id^="attr-form-"]').each(function(index, value) {
                var children = $("#" + this.id).children('.attr');
                var divs = $("#" + this.id).children('.attr-input-div');
                for (var i = 0 ; i < divs.length ; i++) {
                    var attr = divs[i].id.substring(15);
                    if (divs[i].id.indexOf("attr-input-div-cn") == 0) {
                        console.log(divs);
                        console.log($("#attr-" + attr).text().trim());
                        console.log(divs[i].id);
                        console.log($("#" + $("#" + divs[i].id).children()[0].id).val().trim());
                        console.log($("#" + $("#" + divs[i].id).children()[0].id).attr('id'));
                        console.log("-----------");
                    }
                    if ($("#attr-" + attr).text().trim() != $("#" + $("#" + divs[i].id).children()[0].id).val().trim()) {
                        $(this).submit();
                        break;
                    }
                }
            });
                 
            $(this).text("edit");
            $('.attr').show();
            $('.attr-input-div').empty();

            // This forces a reflow to deal with the columns
            $('body').hide();
            setTimeout(function() { $('body').show(); }, 0);
        }
    });
});
