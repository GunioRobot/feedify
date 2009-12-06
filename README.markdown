# Feedify

Feedify is a library with exactly one purpose: Given a URL, determine the location of a feed for that URL if one exists.

You laugh, I can hear you. "Surely that's an easy task" you say. "Just look up the &lt;link&gt;" elements in the html".

Yes, that's what I thought too. But the web is a scary place filled with idiots who redirect you using a status code of 200 and a helpful html page.

Or who provide you with very helpful graphical images you can click on to go to their RSS feed.

And of course many sites provide more than one feed - one for comments, one for entries, etc. with very little to distinguish between them.

Feedify attempts to deal with as many of these misbehaviours as it can, so that you don't have to.

It's almost certainly far from perfect. I've special cased a lot of behaviours based on blogs I read that I knew had weird behaviour: e.g. there's an entire chunk of code just for dealing with blogger's stupid redirect pages. I'm sure more special cases are possible, but I don't know about them. 

So, if you find a URL that this doesn't handle correctly, please file an issue. Better yet: fork it, fix it and send me a pull request! But reports are enough if you don't want to do it yourself.

## HTTP interface

If you want to use this with something that's not ruby, there's an experimental sinatra based http interface to the API.
It's currently pretty basic: Little more than a proof of concept. I may build a service out of it at some point, or if you want to
take it and run with it I'm fine with that too.
