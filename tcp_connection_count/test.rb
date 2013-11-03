require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../network_connections.rb', __FILE__)


class TestNetworkConnections < Test::Unit::TestCase

  def setup
    @options=parse_defaults("network_connections")
  end

  def teardown
  end

  def test_specific_ports
    # Stub the plugin instance where necessary and run
    # @plugin=PluginName.new(last_run, memory, options)
    #                        date      hash    hash
    @plugin=NetworkConnections.new(nil,{},@options)
    @plugin.stubs(:shell).with("netstat -n").returns(FIXTURES[:netstat]).once
    res= @plugin.run()

    # assertions
    reports=res[:reports].first
    assert_equal 6, reports[:tcp]
    assert_equal 0, reports[:udp]
    assert_equal 3, reports[:unix]
    assert_equal 9, reports[:total]
    assert_equal 0, reports["Port 25"]
    assert_equal 0, reports["Port 443"]
    assert_equal 4, reports["Port 80"]
  end

  def test_all_ports
    # Stub the plugin instance where necessary and run
    # @plugin=PluginName.new(last_run, memory, options)
    #                        date      hash    hash
    @plugin=NetworkConnections.new(nil,{},@options.merge(:port=>'all'))
    @plugin.stubs(:shell).with("netstat -n").returns(FIXTURES[:netstat]).once
    res= @plugin.run()

    # assertions
    reports=res[:reports].first
    assert_equal 6, reports[:tcp]
    assert_equal 0, reports[:udp]
    assert_equal 3, reports[:unix]
    assert_equal 9, reports[:total]

    assert_equal 4, reports.keys.size

  end

  FIXTURES=YAML.load(<<-EOS)
    :netstat: |
      Active Internet connections (w/o servers)
      Proto Recv-Q Send-Q Local Address           Foreign Address         State
      tcp        0      0 65.49.73.152:80         67.195.115.234:52044    TIME_WAIT
      tcp        0      0 65.49.73.152:80         67.195.115.234:57047    TIME_WAIT
      tcp        0      0 65.49.73.152:80         77.88.25.26:60633       FIN_WAIT2
      tcp        0      0 65.49.73.152:22         75.36.158.248:53510     ESTABLISHED
      tcp        0      0 65.49.73.152:80         67.195.115.234:57411    TIME_WAIT
      tcp        0      0 65.49.73.152:51289      65.49.73.152:80         TIME_WAIT
      Active UNIX domain sockets (w/o servers)
      Proto RefCnt Flags       Type       State         I-Node   Path
      unix  2      [ ]         DGRAM                    2826     /var/spool/postfix/dev/log
      unix  10     [ ]         DGRAM                    2823     /dev/log
      unix  2      [ ]         DGRAM                    2353     @/org/kernel/udev/udevd
  EOS
end