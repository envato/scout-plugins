require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../solr_stats.rb', __FILE__)

require 'open-uri'
class SolrStatisticsTest < Test::Unit::TestCase

  def teardown
    FakeWeb.clean_registry
  end

  def test_should_report
    uri = 'http://localhost:8983/solr/admin/mbeans'
    body = File.read(File.dirname(__FILE__) + '/fixtures/output.json')
    FakeWeb.register_uri(:get, uri + '?stats=true&wt=json', :body => body)
    
    @plugin = SolrStatistics.new(nil,{},{:location => uri, :handler => '/select'})
    res = @plugin.run()
    stats = res[:reports].first

    assert_equal 500, stats['num_docs']
    assert_equal 501, stats['max_docs']
    assert_equal 0.0032435988363537, stats['avg_rate']
    assert_equal 0.074812428920417, stats['5_min_rate']
    assert_equal 0.14410462363288, stats['15_min_rate']
    assert_equal 81.741, stats['avg_time_per_request']
    assert_equal 82.741, stats['median_request_time']
    assert_equal 84.741, stats['95th_pc_request_time']
  end
end
