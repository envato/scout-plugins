require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../elasticsearch_cluster_status.rb', __FILE__)

require 'open-uri'
class ElasticsearchClusterStatusTest < Test::Unit::TestCase
  def setup
    @options=parse_defaults("elasticsearch_cluster_status")
    setup_urls
  end
  
  def teardown
    FakeWeb.clean_registry    
  end

  def test_initial_run
  	@plugin = ElasticsearchClusterStatus.new(nil,{},@options)
    @res = @plugin.run
    assert @res[:errors].empty?, "Error: #{@res[:errors].inspect}"
    assert @res[:reports].any?
  end

  def test_second_run
  	time = Time.now - 10*60 # 10 minutes ago
  	Timecop.travel(time) do
  		test_initial_run
  		Timecop.travel(time+10*60) do # now
  			plugin = ElasticsearchClusterStatus.new(nil,@res[:memory],@options)
    		res = plugin.run
    		assert res[:errors].empty?, "Error: #{res[:errors].inspect}"
    		assert res[:reports].any?
    		assert_equal 10.to_f, res[:reports].find { |r| r[:query_time] }[:query_time]
    		assert_in_delta (10.to_f/(10*60)), res[:reports].find { |r| r[:query_rate] }[:query_rate]
  		end
  	end
  end

  def test_bad_host
  	 plugin = ElasticsearchClusterStatus.new(nil,{},@options.merge(:elasticsearch_host=>'bad'))
    res = plugin.run
    e = res[:errors].first
    assert e[:body].include?("bad")
  end

  ## helpers

  def setup_urls
    uri="http://127.0.0.1:9200/_cluster/health"
    FakeWeb.register_uri(:get, uri, 
      [
       {:body => File.read("./fixtures/cluster_health.json")},
       {:body => File.read("./fixtures/cluster_health.json")}
      ]
    )
    uri="http://127.0.0.1:9200/_nodes/_local/stats/indices"
    FakeWeb.register_uri(:get, uri, 
      [
       {:body => File.read("./fixtures/indices_stats.json")},
       {:body => File.read("./fixtures/indices_stats_second_run.json")}
      ]
    )
	end
end