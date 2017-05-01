require 'redis'
require 'mongo'
require 'json'

# Implements a memory cache on Redis for persistent documents stored in MongoDb.
# Cache uses Redis's LRU algorithm to discard the least used data.
#
# @author Carlos Westman
#
# @attr [integer] cache_hit_count number of times a query to the Cache hits a result in Redis
# @attr [integer] cache_miss_count number of times a query to the Cache miss a result in Redis
# @attr [integer] cache_hit_avg_time average time in milliseconds for a cache hit to return data
# @attr [integer] cache_miss_avg_time average time in milliseconds for a cache miss to return data
class RedisCache

  attr_accessor :cache_hit_count, :cache_miss_count, :cache_hit_avg_time, :cache_miss_avg_time, :redis_maxmemory

  #Class statistics
  #
  # @example
  #   redis_cache.info #=> {:chache_hitcount=>2, :cache_miss_count=>13, :cache_hit_avg_time=>1, :cache_miss_avg_time=>268}
  #   @return [Hash]
  def info
    {:chache_hitcount => @cache_hit_count,
     :cache_miss_count => @cache_miss_count,
     :cache_hit_avg_time => @cache_hit_avg_time,
     :cache_miss_avg_time => @cache_miss_avg_time,
     :cache_hit_ops_per_sec => (1000 / @cache_hit_avg_time unless @cache_hit_avg_time.nil? ),
     :cache_miss_ops_per_sec => (1000 / @cache_miss_avg_time unless @cache_miss_avg_time.nil?)}
  end

  #reset class statistics and counters
  def reset_info
    @cache_hit_count = 0
    @cache_miss_count = 0
    @cache_hit_total_time = 0
    @cache_miss_total_time = 0
    @cache_hit_avg_time = nil
    @cache_miss_avg_time = nil
  end
  #Initialize the class
  #
  #@example Initialize RedisCache
  #  RedisCache.new(:redis_maxmemory => 100,
  #  :redis_host => 'localhost',
  #  :redis_port => 6379,
  #  :redis_db => 15,
  #  :mongo_host => 'localhost',
  #  :mongo_port => 27017,
  #  :mongo_db => 'testdb')
  #
  # @param [Hash] args the options to initialize the Cache with.
  # @option args [String] :redis_maxmemory (100) Max memory handled by Redis. If a value is stored in Redis when memory usage is bigger than :redis_maxmemory, Redis will discard keys using its LRU algorithm.
  # @option args [String] :redis_host Redis host address
  # @option args [String] :redis_port Redis port
  # @option args [String] :redis_db Redis db name
  # @option args [String] :mongo_host Mongo host address
  # @option args [String] :mongo_port Mongo port
  # @option args [String] :mongo_db Mongo db name
  def initialize **args

    @cache_hit_total_time = 0
    @cache_miss_total_time = 0

    @cache_hit_count = 0
    @cache_miss_count = 0
    @redis_max_memory = args[:redis_maxmemory] || 100

    @redis = Redis.new(:host => args[:redis_host], :port => args[:redis_port], :db => args[:redis_db], :driver => :hiredis)
    Mongo::Logger.logger.level = ::Logger::FATAL
    mongo_client = Mongo::Client.new([ args[:mongo_host].to_s + ':' + args[:mongo_port].to_s ], :database => args[:mongo_db].to_s)
    @mongo =mongo_client.use(args[:mongo_db].to_s)
    @mongo[:proxy].indexes.create_one( { :key => 1 }, unique: true )

    #Configs key storage as an LRU Cache with 500Mb of capacity
    #least used keys will be evicted when writing new data if memory usage gets bigger than 500mb
    @redis.config :set, "maxmemory", (args[:redis_maxmemory].to_i * 1024 * 1024)
    @redis.config :set, "maxmemory-policy", "allkeys-lru"
    @redis.config :set, "maxmemory-samples", 5

  end

  #Writes data in MongoDB
  #
  # @example
  #   result = redis_cache.mongo_write( 'key3', 'value3')
  #   result[:doc] #=> {:key => "key3", :value => "value3"}
  # @param [string] my_key An key that identifies the document
  # @param [string] my_value Document to be stored
  # @return [Hash]
  def mongo_write(my_key, my_value)
    doc = { :key => my_key, :value => my_value }
    #result = @mongo[:proxy].insert_one doc
    result = @mongo[:proxy].update_one( { :key => my_key }, doc, { :upsert => true })
    op_result = { :type => 'write', :destination=> 'mongo', :result => 'OK', :doc => doc, :db_result => result}
  end

  #Reads data from MongoDB
  #
  #@example
  #  redis_cache.mongo_write( 'key4', 'value4')
  #  result = redis_cache.mongo_read 'key4'
  #  result[:doc] #=> {:key => "key4", :value => "value4"}
  #@param [string] my_key An key that identifies the document
  # @return [Hash]
  def mongo_read(my_key)
    #puts my_key
    result_col = @mongo[:proxy].find( { key: my_key } )
    #puts result_col.class
    #puts∫
    result = result_col.first
    #if result.nil?
    #  puts 'pause here'
    #end
    op_result = { :type => 'read', :source=> 'mongo', :result => 'OK', :doc => {:key => result[:key], :value => result[:value] }, :db_result => result}
  end

  #Deletes data from MongoDB
  #
  #@example
  #  redis_cache.mongo_write 'keyB', 'valueB'
  #  result = redis_cache.mongo_delete 'keyB' #=> 1
  #@param [string] my_key An key that identifies the document
  # @return [integer] Number of deleted documents
  def mongo_delete(my_key)
    records_deleted = 0
    @mongo[:proxy].find( { key: my_key } ).each do |doc|
      @mongo[:proxy].delete_one(doc)
      records_deleted += 1
    end
    records_deleted
  end

  #Reads data from Redis
  #
  # @example
  #   redis_cache.redis_write( 'key5', 'value5')
  #   result = redis_cache.redis_read 'key5'
  #   result[:doc] #=> {:key => "key5", :value => "value5"}
  # @param [string] my_key An key that identifies the document
  # @return [Hash]
  def redis_read(my_key)

    result = @redis.get my_key
    if result.nil?
      return op_result = { :type => 'read', :source=> 'redis', :result => nil, :doc => {:key => '', :value => ''}, :db_result => nil}
    else
      json_result = JSON.parse(result)
      return op_result = { :type => 'read', :source=> 'redis', :result => 'OK', :doc => {:key => json_result['key'], :value => json_result['value']}, :db_result => result}
    end
    json_result = JSON.parse(result)
    op_result = { :type => 'read', :source=> 'redis', :result => 'OK', :doc => {:key => json_result['key'], :value => json_result['value']}, :db_result => result}
  end

  #Writes data to Redis
  #
  # @example
  #   result = redis_cache.redis_write( 'key', 'value')
  #   result[:doc] #=> {:key => "key", :value => "value"}
  # @param [string] my_key An key that identifies the document
  # @param [string] my_value Document to be stored
  # @return [Hash]
  def redis_write(my_key, my_value)
    doc = { :key => my_key, :value => my_value }
    result = @redis.set my_key, doc.to_json
    op_result = { :type => 'write', :destination=> 'redis', :result => result, :doc => doc, :db_result => result}
  end

  #Deletes data from Redis
  #
  #@example
  #   redis_cache.redis_write 'keyA', 'valueA'
  #   result = redis_cache.redis_delete 'keyA' #=> 1
  #@param [string] my_key An key that identifies the document
  # @return [integer] Number of deleted documents
  def redis_delete(my_key)
    @redis.del my_key #.unlink my_key #lazy deletino
  end

  #Reads data from Cache
  #
  # @example
  #   result1 = redis_cache.cache_write 'key2' , 'value2'
  #   result2 = redis_cache.cache_read 'key2'
  #   result3 = redis_cache.cache_read 'key2'
  #   result2[:doc] #=> {:key => "key2", :value => "value2"}
  #   result2[:source] #=> 'mongo'
  #   result3[:doc] #=> {:key => "key2", :value => "value2"}
  #   result3[:source] #=> 'redis'
  #@param [string] my_key An key that identifies the document
  # @return [Hash]
  def cache_read my_key

    start_time = Time.now
    result = redis_read my_key

    if result[:result].nil? #cache_miss
      result = mongo_read my_key
      unless result.nil?
        redis_write my_key, result[:doc][:value]
        elapsed_time_ms = ((Time.now - start_time) * 1000 ) #.to_i
        @cache_miss_count += 1
        @cache_miss_total_time += elapsed_time_ms
        @cache_miss_avg_time = @cache_miss_total_time / @cache_miss_count
        return result
      end

    else #cahche_hit
      elapsed_time_ms = ((Time.now - start_time) * 1000 ) #.to_i
      @cache_hit_count += 1;
      @cache_hit_total_time += elapsed_time_ms
      @cache_hit_avg_time = @cache_hit_total_time / @cache_hit_count
      return result
    end

  end

  #Writes data in Cache
  #
  # @example
  #   result = redis_cache.cache_write( 'key', 'value')
  #   result[:doc] #=> {:key => "key", :value => "value"}
  #   result[:destination] #=> 'mongo'
  # @param [string] my_key An key that identifies the document
  # @param [string] my_value Document to be stored
  # @return [Hash]
  def cache_write my_key, my_value
    #I am deleting the key but I could be updating it (collisions are going to happen?)
    #should i upsert instead
    #@redis.set my_key, my_value #before it was del. can i warranty success? and no collitions?
    #@redis.unlink my_key #lazy deletino
    #redis_write my_key, my_value # should i store a key in cache just because it was written?
    redis_delete my_key
    mongo_write my_key, my_value
  end

  #Flushes Redis database
  #
  # @example
  #   redis_cache.cache_flush #=> 'OK'
  #   @return [string] 'OK' if successful
  def cache_flush
    @redis.flushall
  end

end