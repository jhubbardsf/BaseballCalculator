$(function () {
    $(document).on('click', '#form-submit', function(e) {
       $("#main-text").html("Please wait. Calculating...")
    });

    $("#upload-form")
        .bind('ajax:complete', function(xhr, status, error) {
            var most_improved = $.parseJSON(status["responseText"])["most_improved"],
                oakland_players = $.parseJSON(status["responseText"])["oakland_stats"],
                triple_crown = $.parseJSON(status["responseText"])["triple_winner"];

            $("#improved-stats>p").html(most_improved["full_name"] + " has improved by a " + most_improved["difference"] + " difference.");

            $("#slugging-percentages>table>tbody").remove();

            for(var i =0;i < oakland_players.length-1;i++)
            {
                $("#slugging-percentages>table").append("<tbody><tr><td>" + (i+1) + "</td><td>" +
                    oakland_players[i]['full_name'] + "</td><td>" + oakland_players[i]['slugging_percentage'] + "</td></tr></tbody>");

            }

            $("#triple-crown>p").html(triple_crown);

            $("#form-area").fadeOut('fast', function() {
               $("#results-area").fadeIn('fast');
               $("#main-text").html("Results Calculated")
            });

        })

});