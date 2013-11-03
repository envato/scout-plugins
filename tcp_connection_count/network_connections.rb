class NetworkConnections < Scout::Plugin

  OPTIONS=<<-EOS
    port:
      label: Ports
      notes: comma-delimited list of ports to monitor. Or specify all for summary info across all ports.
      default: "80,443,25"
  EOS

  def build_report
    report_hash={}
    port_hash = {}
    if option(:port).strip != "all"
      option(:port).split(/[, ]+/).each { |port| port_hash[port.to_i] = 0 }
    end

    localip_hash = {}
    localips = shell("/sbin/ifconfig -a | awk -F':' '/inet addr/{print $2}' | grep -v '127.0.0.1' | cut -d' ' -f1").split("\n").each { |ip| localip_hash[ip] = port_hash }

    connections_hash = {:tcp => 0,
                        :udp => 0,
                        :unix => 0,
                        :total => 0}

    connections_hash[:tcp]    = shell("netstat -an | awk '/tcp.*ESTAB/{count++} END {print count}'").strip
    connections_hash[:udp]    = shell("netstat -an | awk '/udp.*ESTAB/{count++} END {print count}'").strip
    connections_hash[:unix]   = shell("netstat -an | awk '/unix.*ESTAB/{count++} END {print count}'").strip
    connections_hash[:total]  = shell("netstat -an | awk '/.*ESTAB/{count++} END {print count}'").strip

    shell("netstat -an | awk '/ESTAB/{print $4}'").strip.split("\n").each do |ip_and_port|
      ipaddress = ip_and_port.split(/:/)[0]
      port      = ip_and_port.split(/:/)[1].to_i

      if port_hash.has_key?(port)
	port_hash[port] += 1
	localip_hash[ipaddress][port] += 1 unless ipaddress =~ /127.0.0./
      end
    end    

    connections_hash.each_pair { |conn_type, counter|
      report_hash["Total conn_type"]=counter
    }

    port_hash.each_pair { |port, counter|
      report_hash["Port #{port}"] = counter
    }

    localip_hash.each_pair { |ipaddress, data| 
      data.each_pair { |k, v|
        report_hash["IP #{ipaddress} port #{k}"] = v if ipaddress
      }
    }
    report(report_hash)
  end

  # Use this instead of backticks. It's a separate method so it can be stubbed for tests
  def shell(cmd)
    `#{cmd}`
  end
end
