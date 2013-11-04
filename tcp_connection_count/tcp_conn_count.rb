#
# Created by AJ <andrew.johnson@envato.com>
#
class TcpConnectionCount< Scout::Plugin
  OPTIONS=<<-EOS
    port:
      label: Port
      notes: A Single TCP port to monitor the number of established connections for. Specify 'all' for established connections across all TCP ports
      default: all
  EOS
  def build_report
    tcp_port     = option(:port)
    report_hash  = {}
    report_hash['Total active tcp sessions'] = open_tcp_connections
    local_ip_addresses.each do |ip|
      ip = ip.strip
      next if ip == '127.0.0.1'
      report_hash["#{ip} total active tcp"] = open_tcp_connections_by_ip(ip)

      if tcp_port != 'all'
        report_hash["#{ip} tcp/#{tcp_port} active tcp"] = active_tcp_by_port_and_ip(ip, tcp_port)
      end
    end

    report report_hash
  end

  private

  def local_ip_addresses
    IO.popen("/sbin/ip addr show | awk '/inet /{print $2}' | sed -e 's%/.*%%'").readlines
  end

  def open_tcp_connections
    IO.popen("netstat -an | grep -c '^tcp.*ESTABLISHED'").read.strip
  end

  def open_tcp_connections_by_ip(ipaddr='127.0.0.1')
    IO.popen("netstat -an | grep -c '^tcp.*#{ipaddr}:.*ESTABLISHED'").read.strip
  end

  def open_tcp_connections_by_port(port = tcp_port)
    IO.popen("netstat -an | grep -c '^tcp.*:#{port}.*ESTABLISHED'").read.strip
  end

  def active_tcp_by_port_and_ip(tcp_port, ipaddr)
    IO.popen("netstat -an | grep -c '^tcp.*#{ipaddr}:#{tcp_port}.*ESTABLISHED'").read.strip
  end
end
