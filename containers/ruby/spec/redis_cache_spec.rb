require 'rspec'
require './lib/redis_cache.rb'



describe RedisCache do


    redis_cache = RedisCache.new(:redis_maxmemory => 100,
                                 :redis_host => 'myredis',
                                 :redis_port => 6379,
                                 :redis_db => 15,
                                 :mongo_host => 'mymongo',
                                 :mongo_port => 27017,
                                 :mongo_db => 'testdb')


  describe "A cache" do #move these attributes to an statistics hash
    #it { is_expected.to respond_to(:cache_hit_count)}
    #it { is_expected.to respond_to(:cache_miss_count)}
    #it { is_expected.to respond_to(:cache_hit_avg_time)}
    #it { is_expected.to respond_to(:cache_miss_avg_time)}
    #it { is_expected.to respond_to(:redis_maxmemory)}

    it { is_expected.to respond_to(:cache_hit_count)}
    it { is_expected.to respond_to(:cache_miss_count)}
    it { is_expected.to respond_to(:cache_hit_avg_time)}
    it { is_expected.to respond_to(:cache_miss_avg_time)}
    it { is_expected.to respond_to(:redis_maxmemory)}
  end

  describe "#cache_write" do

    doc = {:key => "key", :value => "value"}
    expected_results = {:type => 'write', :destination =>'mongo', :result => 'OK', :doc => doc}

    result = redis_cache.cache_write( 'key', 'value')

    expected_results.each do |expected_key, expected_value|
      it "on write returns: #{expected_key} as '#{expected_value}'" do
        expect(result[expected_key]).to eq expected_value
      end
    end
  end

  describe "#cache_read" do

    expected_doc = {:key => "key2", :value => "value2"}
    expected_result_1 = {:type => 'write', :destination =>'mongo', :result => 'OK', :doc => expected_doc}
    expected_result_2 =  {:type => 'read', :source =>'mongo', :result => 'OK', :doc => expected_doc}
    expected_result_3 =  {:type => 'read', :source =>'redis', :result => 'OK', :doc => expected_doc}

    result1 = redis_cache.cache_write 'key2' , 'value2'
    result2 = redis_cache.cache_read 'key2'
    result3 = redis_cache.cache_read 'key2'

    expected_result_1.each do |expected_key, expected_value|
      it "on write returns: #{expected_key} as '#{expected_value}'" do
        expect(result1[expected_key]).to eq expected_value
      end
    end

    expected_result_2.each do |expected_key, expected_value|
      it "on first read returns: #{expected_key} as '#{expected_value}'" do
        expect(result2[expected_key]).to eq expected_value
      end
    end

    expected_result_3.each do |expected_key, expected_value|
      it "on second read returns: #{expected_key} as '#{expected_value}'" do
        expect(result3[expected_key]).to eq expected_value
      end
    end
  end

  describe "#cache_flush" do
    it "says OK when excecuted" do
      result = redis_cache.cache_flush
      expect(result).to eq 'OK'
      end
  end

  describe "#mongo_write" do
    expected_doc = {:key => "key3", :value => "value3"}
    expected_results = {:type => 'write', :destination =>'mongo', :result => 'OK', :doc => expected_doc}

    result = redis_cache.mongo_write( 'key3', 'value3')

    expected_results.each do |expected_key, expected_value|
      it "on write returns: #{expected_key} as '#{expected_value}'" do
        expect(result[expected_key]).to eq expected_value
      end
    end
  end

  describe "#mongo_read" do
    expected_doc = {:key => "key4", :value => "value4"}
    expected_results = {:type => 'read', :source =>'mongo', :result => 'OK', :doc => expected_doc}

    redis_cache.mongo_write( 'key4', 'value4')
    result = redis_cache.mongo_read 'key4'


    expected_results.each do |expected_key, expected_value|
      it "on write returns: #{expected_key} as '#{expected_value}'" do
        expect(result[expected_key]).to eq expected_value
      end
    end
  end

  describe "#mongo_delete" do

    redis_cache.mongo_write 'keyB', 'valueB'
    result = redis_cache.mongo_delete 'keyB'
    it "returns '1'" do
      expect(result).to eq 1
    end

  end

  describe "#redis_read" do
    expected_doc = {:key => "key5", :value => "value5"}
    expected_results = {:type => 'read', :source =>'redis', :result => 'OK', :doc => expected_doc}

    redis_cache.redis_write( 'key5', 'value5')
    result = redis_cache.redis_read 'key5'


    expected_results.each do |expected_key, expected_value|
      it "on write returns: #{expected_key} as '#{expected_value}'" do
        expect(result[expected_key]).to eq expected_value
      end
    end
  end

  describe "redis_write" do
    doc = {:key => "key", :value => "value"}
    expected_results = {:type => 'write', :destination =>'redis', :result => 'OK', :doc => doc}

    result = redis_cache.redis_write( 'key', 'value')

    expected_results.each do |expected_key, expected_value|
      it "on write returns: #{expected_key} as '#{expected_value}'" do

        expect(result[expected_key]).to eq expected_value
      end
    end
  end

  describe "redis_delete" do

    redis_cache.redis_write 'keyA', 'valueA'
    result = redis_cache.redis_delete 'keyA'
    it "returns '1'" do
      expect(result).to eq 1
    end

  end

    describe "info" do

      it "returns info" do
        result = redis_cache.info
        expect(result).to be_a(Hash)
      end

    end

end