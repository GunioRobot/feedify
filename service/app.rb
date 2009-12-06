require "rubygems"
require "sinatra"
require "memcache"

$: << "lib"

require "cached_feedify"

UrlMappings = CachedFeedify.new(Memcache.new(:server => "localhost", :namespace => "feedify"))

get "/" do
# Yeah, I'm embedding html in my ruby source. I suck.
<<HTML
<html>
  <head>
    <title>Feedify</title>
  </head>

  <body>
    <p>
      Hi. This is a feedify server. It exists to map URLs to their feeds. Go to /feed/some_url to be redirected
      to the feed for the URL you passed.
    </p>

    <p>
      That's all it does. Were you expecting more?
    </p>
  </body>
</html>
HTML
end

get "/feed/*" do
  redirect UrlMappings.feed_for_url(params["splat"][0]), 303
end
