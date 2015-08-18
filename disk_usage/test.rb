require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../disk_usage.rb', __FILE__)

class DiskUsageTest < Test::Unit::TestCase
    # Stub the plugin instance where necessary and run
    # @plugin=PluginName.new(last_run, memory, options)
    #                        date      hash    hash
    def test_success
      @plugin=DiskUsage.new(nil,{},{})
      @plugin.expects(:`).with("df -h").returns(File.read(File.dirname(__FILE__)+'/fixtures/normal.txt')).once

      res = @plugin.run()
      assert res[:errors].empty?
      assert_equal 4, res[:reports].first.keys.size
      
      r = res[:reports].first
      assert_equal 177.2, r[:avail]
      assert_equal 233.0, r[:size]
      assert_equal 55.8, r[:used]
      assert_equal 24.0, r[:capacity]
    end
    
    def test_multiline
      @plugin=DiskUsage.new(nil,{},{:filesystem=>'/disk2'})
      @plugin.expects(:`).with("df -h").returns(File.read(File.dirname(__FILE__)+'/fixtures/multiline.txt')).once

      res = @plugin.run()
      assert res[:errors].empty?
      assert_equal 4, res[:reports].first.keys.size
      
      r = res[:reports].first
      assert_equal 21.0, r[:avail]
      assert_equal 367.0, r[:size]
      assert_equal 328.0, r[:used]
      assert_equal 95.0, r[:capacity]
    end
    
    def test_block_size
      @plugin=DiskUsage.new(nil,{},{:filesystem=>'/sda6', :command => 'df -B 1G'})
      @plugin.expects(:`).with("df -B 1G").returns(File.read(File.dirname(__FILE__)+'/fixtures/block_size.txt')).once

      res = @plugin.run()
      assert res[:errors].empty?
      assert_equal 4, res[:reports].first.keys.size
      
      r = res[:reports].first
      assert_equal 78.0, r[:available]
      assert_equal 92.0, r[:"1g-blocks"]
      assert_equal 9.0, r[:used]
      assert_equal 11.0, r[:capacity]
    end
end
