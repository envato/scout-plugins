require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../generic_json_uri.rb', __FILE__)

class GenericJsonUriTest < Test::Unit::TestCase
  # Stub the plugin instance where necessary and run
  # @plugin=PluginName.new(last_run, memory, options)
  #                        date      hash    hash
  def test_success
    @plugin=GenericJsonUri.new(nil,{},{:url=>File.expand_path(File.expand_path('../fixtures/test.json', __FILE__))})
    res = @plugin.run()
    assert res[:errors].empty?
    assert_equal 2, res[:reports].first.keys.size

    r = res[:reports].first
    assert_equal 1, r["foo"]
    assert_equal 2, r["bar"]
  end
  
  def test_array
    @plugin=GenericJsonUri.new(nil,{},{:url=>File.expand_path(File.expand_path('../fixtures/array_test.json', __FILE__))})
    res = @plugin.run()
    assert res[:errors].empty?
    assert_equal 3, res[:reports].first.keys.size

    r = res[:reports].first
    assert_equal 3, r["users"]
    assert_equal 4, r["items"]
  end
end