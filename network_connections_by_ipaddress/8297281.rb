class EstablishedConnections < Scout::Plugin

  OPTIONS=<<-EOS
    port:
      label: Ports
      notes: comma-delimited list of ports to monitor. Or specify all for summary info across all ports.
      default: "80,443,25"
    address:
      label: IP Address
      notes: Comma-delimited list of IP addresses to match.  Default:  first detected IP address
      default: 127.0.0.1
  EOS

  def build_report
    match_ip_addresses              = option(:address).split(/[, ]/) if option(:address)
    match_ip_ports                  = option(:port).split(/[, ]/) if option(:address)

    tcp_connections                 = established_tcp_connections

    match_ip_addresses.each do |ip|
      established_connections_by_port = match_ip_ports.each { |port| established_connections_by_port[port] = 0 }
      tcp_connections.each do |localip, port|
        next unless localip == ip
        established_connections_by_port[port] += 1 if established_connections_by_port.has_key?(port)
      end
      established_connections_by_port.each_pair { |port, count| report_hash["#{ip}-tcp-#{port}"] = count }
    end
    
    report(report_hash)
  end

  private

  def established_tcp_connections
    tcp_states = {
      '00' => 'UNKNOWN',  # Bad state ... Impossible to achieve ...
      'FF' => 'UNKNOWN',  # Bad state ... Impossible to achieve ...
      '01' => 'ESTABLISHED',
      '02' => 'SYN_SENT',
      '03' => 'SYN_RECV',
      '04' => 'FIN_WAIT1',
      '05' => 'FIN_WAIT2',
      '06' => 'TIME_WAIT',
      '07' => 'CLOSE',
      '08' => 'CLOSE_WAIT',
      '09' => 'LAST_ACK',
      '0A' => 'LISTEN',
      '0B' => 'CLOSING'
    }
    single_entry_pattern  = Regexp.new(/^\s*\d+:\s+(.{8}):(.{4})\s+(.{8}):(.{4})\s+(.{2})/)
    File.open('/proc/net/tcp','r').each do |line|
      line                = line.strip!
      if match            = line.match( single_entry_pattern )
        connection_state  = match[5]
        next unless connection_state == '01'
        local_ip          = match[1].to_i(16)
        local_port        = local_port.pack("N").unpack("C4").reverse.join('.')
        local_port        = match[2].to_i(16)
        return [local_ip,local_port]
      end
    end
  end

  # Use this instead of backticks. It's a separate method so it can be stubbed for tests
  def shell(cmd)
    `#{cmd}`
  end
end
