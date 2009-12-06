require "feedify"

class CachedFeedify
  include Feedify

  def initialize(memcached, lifetime=7*24*60*60)
    @memcached, @lifetime = memcached, lifetime
  end

  def feed_for_url(url, context=nil)
    result = memcached.get(url)
    return result if result
    result = super.feed_for_url(url, context)
    memcached.set(url, result, @lifetime)
    result
  end
end
