/*
* thanks to Paul Sowden: http://delete.me.uk/2005/03/iso8601.html
 */
Date.prototype.setISO8601 = function (string) {
    var regexp = "([0-9]{4})(-([0-9]{2})(-([0-9]{2})" +
        "(T([0-9]{2}):([0-9]{2})(:([0-9]{2})(\.([0-9]+))?)?" +
        "(Z|(([-+])([0-9]{2}):([0-9]{2})))?)?)?)?";
    var d = string.match(new RegExp(regexp));

    var offset = 0;
    var date = new Date(d[1], 0, 1);

    if (d[3]) { date.setMonth(d[3] - 1); }
    if (d[5]) { date.setDate(d[5]); }
    if (d[7]) { date.setHours(d[7]); }
    if (d[8]) { date.setMinutes(d[8]); }
    if (d[10]) { date.setSeconds(d[10]); }
    if (d[12]) { date.setMilliseconds(Number("0." + d[12]) * 1000); }
    if (d[14]) {
        offset = (Number(d[16]) * 60) + Number(d[17]);
        offset *= ((d[15] == '-') ? 1 : -1);
    }

    offset -= date.getTimezoneOffset();
    time = (Number(date) + (offset * 60 * 1000));
    this.setTime(Number(time));
}

function addComment(comment) {
    var commentDiv, date = new Date()
    date.setISO8601(comment.timestamp);
    
    commentDiv = $("<div class=\"comment-item\"/>");
    commentDiv.append("<p class=\"commentmeta\">Comment by &quot;<span class=\"author\">" + comment.author + "</span>&quot; left <time class=\"timeago\" datetime=\"" + date.toISOString() + "\">" + date.toLocaleString() + "</time></p>");
    commentDiv.append("<blockquote class=\"commentcontent\">" + comment.content + "</blockquote>");
    commentDiv.append("<hr/>");
    commentDiv.find("time.timeago").timeago();

    return commentDiv;
}

function submitComment() {
    $("#comment-submit").attr("disabled", true);
    var author = $("#comment-author").val(), nonce = $("#comment-nonce").val(), content = $("#comment-content").val();

    $.ajax({
	url: "comments.json",
	type: "POST",
	dataType: "json",
	data: {
	    'author': author,
	    'nonce': nonce,
	    'content': content
	},
	success: function(json) {
	    var commentDiv;
	    $("#comment-author").val("");
	    $("#comment-content").val("");

	    commentDiv = addComment(json);
	    commentDiv.hide();
	    $("#comments-list").append(commentDiv);
	    commentDiv.slideDown(600);

	    $("#comment-submit").attr("disabled", false);
	},
	error: function(xhr, status) {
	    var message;
	    try {
		message = $.parseJSON(xhr.responseText);
	    } catch (err) {
		message = {message: "Unknown error."};
	    }

	    $("#comments-list").append("<div class=\"alert alert-error\"><button type=\"button\" class=\"close\" data-dismiss=\"alert\">&times;</button><strong>Error!</strong> " + xhr.statusText + ": " + message.message + "</div>");

	    $("#comment-submit").attr("disabled", false);
	}
    });

    return false;
}

function loadComments(divID, path) {
    $.ajax({
	url: path,
	type: "GET",
	dataType: "json",
	success: function(json) {
	    var commentsListDiv, commentsDiv = $(divID), length = json.comments.length;
	    commentsDiv.hide();

	    commentsDiv.empty();
	    commentsDiv.append("<p><a href=\"#post-your-comment\">Post your comment</a>.</p>");

	    commentsListDiv = $("<div id=\"comments-list\"/>");
	    for (var i = 0; i < length; i++) {
		commentsListDiv.append(addComment(json.comments[i]));
	    }
	    commentsDiv.append(commentsListDiv);

	    var form = $("<form id=\"new-comment\" action=\"javascript:submitComment()\" accept-charset=\"utf-8\"></form>");
	    form.append("<h4><a name=\"post-your-comment\"></a>Post your comment</h4>");
	    form.append("<input type=\"hidden\" id=\"comment-nonce\" name=\"comment-nonce\" value=\"" + json.nonce + "\"/>");
	    form.append("<p><label for=\"comment-author\">Your name:</label><input type=\"text\" id=\"comment-author\" name=\"comment-author\"/><br/><label for=\"comment-content\">Your comment: <small>(Some Markdown is permitted, but HTML is not.)</small></label><textarea id=\"comment-content\" name=\"comment-content\"/></p><p><input type=\"submit\" id=\"comment-submit\" name=\"comment-submit\" value=\"Post your comment\"/></p>");
	    commentsDiv.append(form);

	    commentsDiv.slideDown(600);
	},
	error: function(xhr, status) {
	}
    });
}
