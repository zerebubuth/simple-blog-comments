Simple Blog Comments
====================

Simple Blog Comments is a very simple
[Sinatra](http://www.sinatrarb.com/) application to serve a very
simple, linear set of comments over a bunch of pages. This can be
integrated into your blog or CMS by including the `comments.js` script
and annotating an element with the ID "comments". 

For example, in the content of your page:

```html
<section>
  <h3>Comments</h3>
  <div id="comments"><em>Comments loading...</em></div>
</section>
```

And towards the end:

```html
<script src="<%= url_to('js/jquery-1.9.1.min.js') %>"></script>
<script src="<%= url_to('js/jquery.timeago.js') %>"></script>
<script src="<%= url_to('js/comments.js') %>"></script>
<script>
  $(document).ready(function() {
    loadComments("#comments", "comments.json");
  });
</script>
```

Note that this requires [JQuery](http://jquery.com/) and the
[timeago](http://timeago.yarp.com/) plugin.

Finally, you *will* need to edit the `comments.rb` file, as there are
some constants defined at the top which reference places on the
filesystem to find static files, or put comment entries.
