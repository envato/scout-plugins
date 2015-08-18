class MemcachedStats < Scout::Plugin
  needs 'socket'

  OPTIONS = <<-EOS
  host:
    name: Host
    notes: The host to monitor
    default: 127.0.0.1
  port:
    name: Port
    notes: The port memcached is running on
    default: 11211
  EOS

  KILOBYTE = 1024
  MEGABYTE = 1048576

  def build_report
    stats = memcached_stats

    report(:uptime_in_hours       => stats['uptime'].to_f / 60 / 60)
    report(:used_memory_in_mb     => stats['bytes'].to_i / MEGABYTE)
    report(:limit_in_mb           => stats['limit_maxbytes'].to_i / MEGABYTE)
    report(:curr_items            => stats['curr_items'].to_i)
    report(:total_items           => stats['total_items'].to_i)
    report(:curr_connections      => stats['curr_connections'].to_i)
    report(:threads               => stats['threads'].to_i)

    counter(:gets_per_sec,        stats['cmd_get'].to_i,     :per => :second)
    counter(:sets_per_sec,        stats['cmd_set'].to_i,     :per => :second)
    counter(:hits_per_sec,        stats['get_hits'].to_i,    :per => :second)
    counter(:misses_per_sec,      stats['get_misses'].to_i,  :per => :second)
    counter(:evictions_per_sec,   stats['evictions'].to_i,   :per => :second)

    counter(:kilobytes_read_per_sec,    (stats['bytes_read'].to_i / KILOBYTE),    :per => :second)
    counter(:kilobytes_written_per_sec, (stats['bytes_written'].to_i / KILOBYTE), :per => :second)
  rescue Errno::ECONNREFUSED => e
    return error( "Could not connect to Memcached.",
                  "Make certain you've specified the correct host and port: \n\n#{e}\n\n#{e.backtrace}" )
  end

  def memcached_stats
    data = {}
    TCPSocket.open(option(:host), option(:port)) do |connection|
      connection.puts('stats')

      while line = connection.gets.strip
        break if line == 'END'
        
        line = line.split(/\s/)
        data[line[1]] = line[2]
      end
    end
    data
  end

end
