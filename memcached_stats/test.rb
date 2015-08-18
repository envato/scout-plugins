require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../memcached_stats.rb', __FILE__)

class MemcachedStatsTest < Test::Unit::TestCase

  def test_default_to_host_and_port
    result = MemcachedStats.new(nil, {}, {:host => 'localhost', :port => 11212}).run
    assert_equal 1, result[:errors].size

    error = result[:errors].first
    assert_equal "Could not connect to Memcached.", error[:subject]
    assert error[:body].include?("Make certain you've specified the correct host and port:")
  end

  def test_stats_run
    time = Time.now
    StringIO.any_instance.stubs(:puts).with('stats').returns(true)
    TCPSocket.stubs(:open).with('localhost', 11212).yields(first_run_data).once

    result = Timecop.travel(time) do
      MemcachedStats.new(nil, {}, {:host => 'localhost', :port => 11212}).run
    end

    assert_equal 7, result[:reports].size
    assert_equal 0.25, get_data_from_result_for(result, :uptime_in_hours)
    assert_equal 1, get_data_from_result_for(result, :used_memory_in_mb)
    assert_equal 64, get_data_from_result_for(result, :limit_in_mb)
    assert_equal 0, get_data_from_result_for(result, :curr_items)
    assert_equal 0, get_data_from_result_for(result, :total_items)
    assert_equal 10, get_data_from_result_for(result, :curr_connections)
    assert_equal 4, get_data_from_result_for(result, :threads)

    TCPSocket.stubs(:open).with('localhost', 11212).yields(second_run_data).once
    result = Timecop.travel(time + 60) do
      MemcachedStats.new(nil, result[:memory], {:host => 'localhost', :port => 11212}).run
    end
    assert_equal 14, result[:reports].size

    assert_equal 0.5, get_data_from_result_for(result, :uptime_in_hours)
    assert_equal 0, get_data_from_result_for(result, :used_memory_in_mb)
    assert_equal 64, get_data_from_result_for(result, :limit_in_mb)
    assert_equal 0, get_data_from_result_for(result, :curr_items)
    assert_equal 0, get_data_from_result_for(result, :total_items)
    assert_equal 10, get_data_from_result_for(result, :curr_connections)
    assert_equal 4, get_data_from_result_for(result, :threads)

    # The following assertions with floast end up being near a float, for now
    # we'll just assert that the data is there
    assert get_data_from_result_for(result, :gets_per_sec)
    assert get_data_from_result_for(result, :sets_per_sec)
    assert get_data_from_result_for(result, :hits_per_sec)
    assert get_data_from_result_for(result, :misses_per_sec)
    assert get_data_from_result_for(result, :evictions_per_sec)
    assert get_data_from_result_for(result, :kilobytes_read_per_sec)
    assert get_data_from_result_for(result, :kilobytes_written_per_sec)
  end

  private

  def get_data_from_result_for(result, name)
    result[:reports].find{|r| r[name] }[name]
  end

  def first_run_data
    StringIO.new(<<-DATA)
      STAT pid 35515
      STAT uptime 900
      STAT time 1392692600
      STAT version 1.4.16
      STAT libevent 2.0.21-stable
      STAT pointer_size 64
      STAT rusage_user 0.002410
      STAT rusage_system 0.005216
      STAT curr_connections 10
      STAT total_connections 11
      STAT connection_structures 11
      STAT reserved_fds 20
      STAT cmd_get 0
      STAT cmd_set 0
      STAT cmd_flush 0
      STAT cmd_touch 0
      STAT get_hits 0
      STAT get_misses 0
      STAT delete_misses 0
      STAT delete_hits 0
      STAT incr_misses 0
      STAT incr_hits 0
      STAT decr_misses 0
      STAT decr_hits 0
      STAT cas_misses 0
      STAT cas_hits 0
      STAT cas_badval 0
      STAT touch_hits 0
      STAT touch_misses 0
      STAT auth_cmds 0
      STAT auth_errors 0
      STAT bytes_read 6
      STAT bytes_written 0
      STAT limit_maxbytes 67108864
      STAT accepting_conns 1
      STAT listen_disabled_num 0
      STAT threads 4
      STAT conn_yields 0
      STAT hash_power_level 16
      STAT hash_bytes 524288
      STAT hash_is_expanding 0
      STAT malloc_fails 0
      STAT bytes 1048576
      STAT curr_items 0
      STAT total_items 0
      STAT expired_unfetched 0
      STAT evicted_unfetched 0
      STAT evictions 0
      STAT reclaimed 0
      END
    DATA
  end

  def second_run_data
    StringIO.new(<<-DATA)
      STAT pid 35515
      STAT uptime 1800
      STAT time 1392693646
      STAT version 1.4.16
      STAT libevent 2.0.21-stable
      STAT pointer_size 64
      STAT rusage_user 0.015935
      STAT rusage_system 0.028168
      STAT curr_connections 10
      STAT total_connections 11
      STAT connection_structures 11
      STAT reserved_fds 20
      STAT cmd_get 0
      STAT cmd_set 0
      STAT cmd_flush 0
      STAT cmd_touch 0
      STAT get_hits 0
      STAT get_misses 0
      STAT delete_misses 0
      STAT delete_hits 0
      STAT incr_misses 0
      STAT incr_hits 0
      STAT decr_misses 0
      STAT decr_hits 0
      STAT cas_misses 0
      STAT cas_hits 0
      STAT cas_badval 0
      STAT touch_hits 0
      STAT touch_misses 0
      STAT auth_cmds 0
      STAT auth_errors 0
      STAT bytes_read 12
      STAT bytes_written 1044
      STAT limit_maxbytes 67108864
      STAT accepting_conns 1
      STAT listen_disabled_num 0
      STAT threads 4
      STAT conn_yields 0
      STAT hash_power_level 16
      STAT hash_bytes 524288
      STAT hash_is_expanding 0
      STAT malloc_fails 0
      STAT bytes 0
      STAT curr_items 0
      STAT total_items 0
      STAT expired_unfetched 0
      STAT evicted_unfetched 0
      STAT evictions 0
      STAT reclaimed 0
      END
    DATA
  end

end