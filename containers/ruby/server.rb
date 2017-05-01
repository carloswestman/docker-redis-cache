#!/usr/bin/env ruby

require './lib/redis_cache'
require 'chunky_png'
require 'sinatra'

environment = ENV['NAME']
redis_server = 'localhost' if environment.nil?
redis_server = 'myredis' if environment == 'docker'
mongo_server = 'localhost' if environment.nil?
mongo_server = 'mymongo' if environment == 'docker'
puts "environment: #{environment}"

class WEBAPI_METHODS
  attr_accessor :proxy
  def initialize(my_proxy)
    @proxy = my_proxy
  end
  def proxy_read
    proxy.cache_read 1
  end
  def proxy_write
    proxy.cache_write 1
  end
  def proxy_redis_matches
    proxy.redis_hit_count
  end
  def proxy_mong_matches
    proxy.redis_hit_count
  end
  def proxy_redis_memory
    100
  end
end

#add suport to conf via env variables?
proxy = RedisCache.new(:redis_maxmemory => 100,
                       :redis_host => redis_server,
                       :redis_port => 6379,
                       :redis_db => 15,
                       :mongo_host => mongo_server,
                       :mongo_port => 27017,
                       :mongo_db => 'test')

web_methods = WEBAPI_METHODS.new proxy

#some testing
#a =  proxy.redis_info['used_memory']
#puts "Used Memory:"
#puts a

#a =  proxy.redis_dbsize
#puts "Number of keys:"
#puts a

#111.times do |timex|
#  puts "#{(proxy.proxy_write timex, timex)}"
#end

def imagen(proxy, path)
  png = ChunkyPNG::Image.new(150, 150, ChunkyPNG::Color::TRANSPARENT)
  marker_red = ChunkyPNG::Color.rgba(100, 0, 0, 255) #red
  marker_blue = ChunkyPNG::Color.rgba(0, 0, 100, 255) #blue
  marker_yellow = ChunkyPNG::Color('yellow') #blue
  data = ChunkyPNG::Color.rgba(0, 100, 0, 255) #green
  empty = ChunkyPNG::Color('grey @ 0.5')

  (1..22500).each do |time|

    if yield time
      color = empty
    else
      color = data
    end
    png[((time - 1) % 150)  , (149) - ((time -1 )/150).to_i  ]  = color
  end

  png[0,0] = marker_red
  png[1,0] = marker_red
  png[2,0] = marker_red
  png[3,0] = marker_red
  png[((1-1)% 150)  ,(149) - ((1 -1 )/150).to_i] = marker_blue #{%}"marker at key= 0
  png[((20-1) % 150) ,(149) - ((20 -1 )/150).to_i] = marker_blue #{%}"marker at key= 20
  png[((40-1) % 150) ,(149) - ((40 -1 )/150).to_i] = marker_blue #{%}"marker at key= 40
  png[((60-1) % 150) ,(149) - ((60 -1 )/150).to_i] = marker_blue #{%}"marker at key= 60
  png[((22500 -1) % 150) ,(149) - ((22500 -1 )/150).to_i] = marker_yellow #{%}"marker at key= yellow


  png.save(path, :interlace => true)
end

def test(proxy)
  number_messages = 22500
  message_size_bytes = 1024 * 5
  message = '0' * message_size_bytes



  proxy.cache_flush #it doesn't delete Mongo previously stored data
  proxy.reset_info
  puts "* How a proxy looks at start:"
  puts proxy.info
  imagen(proxy, '1 start.png') { |i| (proxy.redis_read i)[:result].nil?}

  #Write sequencial data into the Cache
  puts "* Start sequential write. No. messages: #{number_messages}, Message size: #{number_messages}"
  proxy.reset_info
  key = 0
  while key < number_messages do
    key +=1
    proxy.cache_write key, message
    puts "  progress #{(100 * key / number_messages).to_i}% #{proxy.info}" if (key % (number_messages / 10)) == 0
  end

  puts "Cache info after sequential write"
  puts proxy.info
  puts "Cache hits throughput: #{proxy.info[:cache_hit_ops_per_sec] * message_size_bytes unless proxy.info[:cache_hit_ops_per_sec].nil? } [bytes/sec]"
  puts "Cache miss throughput: #{proxy.info[:cache_miss_ops_per_sec] * message_size_bytes unless proxy.info[:cache_miss_ops_per_sec].nil?} [bytes/sec]"
  imagen(proxy, '2 sequential write.png') { |i| (proxy.redis_read i)[:result].nil?}


  #read cache
  puts "* Start sequential read. No. messages: #{number_messages}, Message size: #{number_messages}"
  proxy.reset_info
  key = 0
  while key < number_messages do
    key +=1
    proxy.cache_read key
    puts "  progress #{(100 * key / number_messages).to_i}% #{proxy.info}" if (key % (number_messages / 10)) == 0
  end

  puts "Cache info after sequential read"
  puts proxy.info
  puts "Cache hits throughput: #{proxy.info[:cache_hit_ops_per_sec] * message_size_bytes unless proxy.info[:cache_hit_ops_per_sec].nil? } [bytes/sec]"
  puts "Cache miss throughput: #{proxy.info[:cache_miss_ops_per_sec] * message_size_bytes unless proxy.info[:cache_miss_ops_per_sec].nil?} [bytes/sec]"
  imagen(proxy, '3 sequential read.png') { |i| (proxy.redis_read i)[:result].nil?}

  #read cache (randomly), there are going to be some cache misses here
  puts "* Start random read. No. messages: #{number_messages}, Message size: #{number_messages}"
  proxy.reset_info
  counter = 1
  (1..number_messages).each do
    counter += 1
    key = 1 + rand(number_messages)
    proxy.cache_read key
    puts "  progress #{(100 * counter / number_messages).to_i}% #{proxy.info}" if (counter % (number_messages / 10)) == 0
  end

  puts "Cache info after random read"
  puts proxy.info
  puts "Cache hits throughput: #{proxy.info[:cache_hit_ops_per_sec] * message_size_bytes unless proxy.info[:cache_hit_ops_per_sec].nil? } [bytes/sec]"
  puts "Cache miss throughput: #{proxy.info[:cache_miss_ops_per_sec] * message_size_bytes unless proxy.info[:cache_miss_ops_per_sec].nil?} [bytes/sec]"
  imagen(proxy, '4 random read.png') { |i| (proxy.redis_read i)[:result].nil?}

end



test(proxy)
