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
      super("After traversing #{urls.join(" -> ")} -> #{urls[0]} we seem to be back where we started")
    end
  end

  class BadScheme < FeedifyError 
    def initialize(scheme)
      super("Feedify only deals with http. Why are you giving me a #{scheme} URI?")
    end
  end

  class Context
    attr_accessor :base_uri

    def initialize(url)
      @base_uri = URI.parse(url)
      @urls = []
    end

    def visit(url)
      if @urls.include?(url)
        raise Loop.new(@urls)
      else
        @urls << url
      end
    end
  end

  def feed_for_url(url, context=Context.new(fix_url(url)))
    return nil unless url
    url = fix_url(url)
    file = open(url)
    location = file.meta["Location"]
    # TODO: Loop detection
    if location && (location != url)
      feed_for_url(location, context)
    elsif file.content_type =~ /atom|rss|xml/
      url
    elsif file.content_type =~ /html/
      feed_for_url(feed_for_html(file.read, context), context)
    else
      raise UnrecognisedMimeType.new(url, feed.content_type)
    end or raise NoFeed.new(url)
  end

  private 
  def feed_for_html(html, context)
    feed_for_parse(Nokogiri::HTML(html), context)
  end

  def feed_for_parse(html, context)
    feed_from_alternative_links(html, context) ||
    feed_for_blogger_redirect(html, context) ||
    feed_from_in_page_hrefs(html, context) 
  end

  def feed_from_alternative_links(html, context)
    links = html.xpath('//link[@rel="alternate"]').select{|x| x["type"] =~ /atom|rss/}

    if links.empty?
      return
    end
    
    if links.length > 1
      # prefer atom over rss due to snobbery
      atom_only = links.select{|x| x["type"] =~ /atom/}
      links = atom_only unless atom_only.empty?
  
      if links.length > 1 
        # a lot of blogs have comments links. we don't want those
        no_comments = links.reject{|x| x["href"] =~ /comments/}

        links = no_comments unless no_comments.empty?
      end
    end
    
    # Hopefully we've got only one link here, modulo duplicate URLS
    # If not, we give up and guess
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

  def feed_from_in_page_hrefs(html, context)
    candidates = (html.xpath('//a') + html.xpath('//img[@href]')).select{|i| quick_and_dirty_url_filter(i['href'])}

    return if candidates.empty?

    selective = candidates.select{|x| x.to_s =~ /(atom|feed|rss)\b/}

    candidates = selective if !selective.empty?

    candidates = candidates.map{|x| x["href"]}.compact.uniq.map{|x| (context.base_uri + URI.parse(x)).to_s}

    candidates[0] 
  end

  # A very quick pass over URLs to determine if it's at all possible that they
  # are a feed or not worth bothering with. This should never return false for
  # a feed URL but will often return true for non feed URLs.
  def quick_and_dirty_url_filter(url)
    url && (url !~ /\.(css|js|htm(l?)|jpg|gif|zip|jnlp)$/) && (url !~ /^#/)
  end

  def fix_url(url)
    url = url.strip
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
