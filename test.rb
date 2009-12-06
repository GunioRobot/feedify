#!/usr/bin/env ruby

load "#{File.dirname(__FILE__)}/lib/feedify.rb"

def run_tests
  failing = 0

  File.open(File.dirname(__FILE__) + "/test_urls").read.split("\n").each{|line|
    line = line.gsub(/#.+$/, "").strip
    next if line.length == 0

    from, to = line.split

    to = to.strip

    if to =~ /^[[:alnum:]]+$/
      puts "testing that #{from} has no feed and throws a #{to}"
      begin 
        actual = Feedify.feed_for_url(from) 
        failing += 1
        puts "  ...but it actually maps to #{actual}"
      rescue Feedify::FeedifyError => e
        unless e.class.to_s == "Feedify::#{to}"
          puts " ...but it actually throws a #{e.class}"
        end
      end
    else
      puts "testing that #{from} maps to #{to}"
   
      if (actual = Feedify.feed_for_url(from)) != to
        failing += 1
        puts "  ...but it actually maps to #{actual}"
      end
    end
  }
  failing
end

if __FILE__ == $0
  failing = run_tests

  if failing > 0
    puts "Completed with #{failing} tests failing"
    exit 1
  else
    puts "Completed with no tests failing"
  end
end
