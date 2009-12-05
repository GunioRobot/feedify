# Feedify

Feedify is a library with exactly one purpose: Given a URL, determine the location of a feed for that URL if one exists.

You laugh, I can hear you. "Surely that's an easy task" you say. "Just look up the <link" elements in the html".

Yes, that's what I thought too. But the web is a scary place filled with idiots who redirect you using a status code of 200 and a helpful html page.

Or who provide you with very helpful graphical images you can click on to go to their RSS feed.

And of course many sites provide more than one feed - one for comments, one for entries, etc. with very little to distinguish between them.

Feedify attempts to deal with as many of these misbehaviours as it can, so that you don't have to.
