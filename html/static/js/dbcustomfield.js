
var $ = jQuery; // RT doesn't do that for us.

$( function() {
    $('input[data-dbcustomfield-source]').each(function () {
        var $dbCustomFieldInput = $(this);
        var $dbCustomFieldSearch = $dbCustomFieldInput.parent('.rt-extension-dbcustomfield-search');

    	$('.clear-field-value', $dbCustomFieldSearch).on('click', function (event) {
    		$('.selected-field-value span', $dbCustomFieldSearch).html('<% loc('(no value)') | n %>');
    		$('input[type="hidden"]', $dbCustomFieldSearch).val('');

    		event.preventDefault();
    		return false;
    	});

        $dbCustomFieldInput.autocomplete({
    		delay: 500,
    		minLength: 2,
    		open: function() {
    			if ($(this).is(':not(:focus)')) {
    				$(this).autocomplete('close');
    			}
    		},
    		source: function (request, response){
    			$.ajax({
    				type: "POST",
    				url: '<% RT->Config->Get('WebURL') | n %>RT-Extension-DBCustomField/Provider.html',
    				dataType: "json", // let JQuery automatically convert the response to JSON.
                    data: {
                        query: request.term,
                        source: $dbCustomFieldInput.data('dbcustomfield-source'),
                        objectId: $dbCustomFieldInput.data('dbcustomfield-objectId'),
                        objectType: $dbCustomFieldInput.data('dbcustomfield-objectType')
                    },
    				success: function (data, text) {
    					var result = [];
    					$.each(data.result, function (i, el) {
    						result.push({
                                label: el[2],
                                value: {
                                    field_value: el[0],
                                    display_value: el[1]
                                }
                            });
    					});

    					response(result);
    				},
    				error: function (request, status, error) {
    					// TODO: Remove
    					//console.log("error: " + request.responseText);
    				}
    			});
    		},
    		select: function(event, ui) {
                // Clear the input. Prevents the user from thinking it's possible to change the selection by simply typing..
    			$dbCustomFieldInput.val('');

                // Shows the chosen value to the user
    			$('.selected-field-value span', $dbCustomFieldSearch).html(ui.item.value.display_value);

                // Inserts the actual field value into the hidden input
    			$('input[type="hidden"]', $dbCustomFieldSearch).val(ui.item.value.field_value);

    			// tell autocomplete that the select event has set a value
    			return false;
    		}
    	});
    });
});
