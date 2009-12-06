require "feedify"

class CachedFeedify
  include Feedify

  def initialize(memcached, lifetime=7*24*60*60)
    @memcached, @lifetime = memcached, lifetime
  end

  def feed_for_url(url, context=nil)
    result = @memcached.get(url)    
    if result
      return result 
    end
    result = super
    @memcached.set(url, result, @lifetime)
    result
  end
end
