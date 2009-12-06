require "rubygems"
require "uri"
require "open-uri"
require "nokogiri"
require "set"

module Feedify
  class FeedifyError < Exception
  end
  
  class BloggerError < FeedifyError
    attr_accessor :html
    def initialize(html)
      super("Something went wrong with our blogger html parsing")
      @html = html
    end
  end

  class UnrecognisedMimeType < FeedifyError
    attr_accessor :mime, :url

    def initialize(mime, url)
      super("I don't know what to do with the mime type #{mime} for the URL #{url}")
      @mime, @url = mime, url
    end
  end

  class NoFeed < FeedifyError
    def initialize(url)
      super("As best as we can determine there is no feed for #{url}")
    end
  end

  class Loop < FeedifyError
    def initialize(urls)
      super("After traversing #{urls.join(" -> ")} we seem to have hit a loop")
    end
  end

  class BadScheme < FeedifyError 
    def initialize(scheme)
      super("Feedify only deals with http. Why are you giving me a #{scheme} URI?")
    end
  end

  class Confused < FeedifyError
    def initialize(urls)
      super("I'm sorry, I found all these URLs and didn't know how to decide between them: #{urls.join(", ")}")
    end
  end

  class MissingPage < FeedifyError
    def initialize(url)
      super("Something pointed me at the URL #{url} but it wasn't there")
    end
  end

  class Context
    attr_accessor :base_uri

    def initialize(url)
      @base_uri = URI.parse(url)
      @urls = []
    end

    def visit(url)
      if @urls[0..-2].include?(url)
        @urls << url
        raise Loop.new(@urls)
      else
        @urls << url
      end
    end
  end

  # Takes a url as a string, returns a URL of a feed for it as a string 
  # or throws an exception. 
  # Returns nil if you pass it nil, but given a non-nil URL it will always
  # return a non-nil feed url or throw an exception.
  def feed_for_url(url, context=nil)    
    return nil unless url

    begin 
      url = fix_url(url)
      context ||= Context.new(url)
      context.visit(url)
      file = open(url)
      location = file.base_uri.to_s
      
      if location && (location != url)
        feed_for_url(location, context)
      elsif valid_content_type?(file.content_type)
        url
      elsif file.content_type =~ /html/
        discovered = feed_for_html(file.read, context)
        if discovered
          feed_for_url((URI.parse(url) + URI.parse(discovered)).to_s, context)
        end
      else
        raise UnrecognisedMimeType.new(url, feed.content_type)
      end or raise NoFeed.new(url)
    rescue SocketError
      if $!.message == "getaddrinfo: Name or service not known"
        raise MissingPage.new(url)
      else raise
      end
    end
  end

  def feed_for_html(html, context)
    feed_for_parse(Nokogiri::HTML(html), context)
  end

  def feed_for_parse(html, context)
    feed_from_alternative_links(html, context) ||
    feed_for_blogger_redirect(html, context) ||
    feed_from_in_page_hrefs(html, context) 
  end

  def prune_elements(links)
    links = links.select{|x| quick_and_dirty_url_filter(x["href"])}

    selective = links.select{|x| x.to_s =~ /(atom|feed|rss)\b/}
    links = selective if !selective.empty?

    if links.length > 1
      # prefer atom over rss due to snobbery
      atom_only = links.select{|x| 
        if x["type"]
          x["type"] =~ /\batom\b/
        else
          x.to_s =~ /\batom\b/
        end
      }
      links = atom_only unless atom_only.empty?
  
      if links.length > 1 
        # a lot of blogs have comments links. we don't want those
        no_comments = links.reject{|x| x["href"] =~ /comments/}

        links = no_comments unless no_comments.empty?
      end
    end
    links
  end

  def feed_from_alternative_links(html, context)
    links = html.xpath('//link[@rel="alternate"]').select{|x| x["type"] =~ /atom|rss/}

    if links.empty?
      return
    end

    links = prune_elements(links)
    # Hopefully we've got only one link here, modulo duplicate URLS
    # If not, we give up and guess. They're probably all ok.
    links.map{|l| l["href"]}.uniq[0] 
  end

  def feed_for_blogger_redirect(html, context)
    title = html.xpath("//title").text.strip
    # Blogger sometimes shows a useless redirect page which gives you 
    # no actual helpful information. Blogger blogs are popular enoguh
    # that we special case this.
    if(title == "Blogger: Redirecting")
      url = html.xpath('//a[@id="continueButton"]')[0]['href'] 

      if !url
        raise BloggerError.new(html)  
      end

      return feed_for_url(url, context)
    end  
  end

  SMALL_NUMBER_OF_LINKS = 5

  def feed_from_in_page_hrefs(html, context)
    candidates = prune_elements(html.xpath('//a') + html.xpath('//img[@href]'))

    return if candidates.empty?

    candidates = candidates.map{|x| x["href"]}.compact.uniq.map{|x| (context.base_uri + URI.parse(x)).to_s}

    raise Confused.new(candidates) if candidates.length > SMALL_NUMBER_OF_LINKS 
    
    # We've only got a few possibilities, so let's just check them and find out if they look like feeds!
    candidates = candidates.select{|x| is_a_feed?(x)}
 
    raise Confused.new(candidates) if candidates.length > 1

    candidates[0] 
  end

  # Expensive test for feedhood. Has to fetch the URL
  def is_a_feed?(url)
    it = begin
      open(url)    
    rescue OpenURI::HTTPError
      return false
    end

    return false if !valid_content_type?(it.content_type)
    return false unless it.read =~ /<channel|feed[^>]*?>/ # Why yes, this is a hack. Why do you ask?

    true
  end

  def valid_content_type?(type)
    type =~ /atom|rss|xml/
  end

  # A very quick pass over URLs to determine if it's at all possible that they
  # are a feed or not worth bothering with. This should never return false for
  # a feed URL but will often return true for non feed URLs.
  def quick_and_dirty_url_filter(url)
    url && (url !~ /\.(css|js|htm(l?)|jpg|gif|zip|jnlp)$/) && (url !~ /^#/)
  end

  def fix_url(url)
    url = url.strip

    url = url.gsub(/^feed:/, "http:")

    scheme = URI.parse(url).scheme
    case scheme 
      when nil: "http://#{url.strip.gsub(/^\/*/, "")}"
      when "http": url
      else raise BadScheme.new(scheme) 
    end    
  end

end

class <<Feedify
  include Feedify
end
