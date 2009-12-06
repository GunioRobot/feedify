require "rubygems"
require "sinatra"
require "memcache"

$: << "../lib"

require "cached_feedify"

UrlMappings = CachedFeedify.new(Memcache.new(:server => "localhost", :namespace => "feedify"))

get "/" do
  send_file "public/index.html"
end

get "/feed/*" do
  response.headers['Cache-Control'] = "public, max-age=#{60*60*24*7}" 
  redirect UrlMappings.feed_for_url(params["splat"][0]), 302
end
