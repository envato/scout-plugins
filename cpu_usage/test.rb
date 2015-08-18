require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../cpu_usage.rb', __FILE__)

class CpuUsageTest < Test::Unit::TestCase
    # Stub the plugin instance where necessary and run
    # @plugin=PluginName.new(last_run, memory, options)
    #                        date      hash    hash
    def test_success
      data = File.read(File.dirname(__FILE__)+'/fixtures/proc_stat.txt')
      #File.stubs(:read).with("/proc/stat").returns(data)
      time = Time.now
      
      Timecop.travel(time-60*10) do 
        @plugin=CpuUsage.new(nil,{},{})
        CpuUsage::CpuStats.stubs(:`).with("cat /proc/stat 2>&1").returns(File.read(File.dirname(__FILE__)+'/fixtures/proc_stat.txt'))
        
        res = @plugin.run()
        assert_equal 9, res[:memory][:cpu_stats].size
        first_run_memory = res[:memory]
        
        Timecop.travel(time) do
          @plugin=CpuUsage.new(nil,first_run_memory,{})
          res = @plugin.run()
          assert_equal 7, res[:reports].first.size
        end # timecop
      end # timecop
    end # test_success
  
end