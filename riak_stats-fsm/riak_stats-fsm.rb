# Copyright (c) 2014 Goldstar Events, Inc.
# Patrick O'Brien (pobrien@goldstar.com)
# Copyright (c) 2011 Mad Mimi, LLC
# Marc Heiligers (marc@madmimi.com)
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
# and associated documentation files (the "Software"), to deal in the Software without restriction, 
# including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, 
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial 
# portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT 
# LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class RiakStatsFSM < Scout::Plugin
  needs 'net/http'
  needs 'resolv'
  needs 'json'
  
  OPTIONS = <<-EOF
    use_dns_hostname:
      default: false
      name: Lookup Stats IP From DNS
      notes: Use the IP found in DNS (rather than what is found in /etc/hosts).
    stats_port:
      default: '8098'
      name: Stats Port
      notes: The port that will be queried for JSON formatted stats.
    stats_path:
      default: 'stats'
      name: Stats Path
      notes: The path for the stats endpoint.
  EOF
  
  def build_report
    fsm_stats  = %w{node_get_fsm_time_100 node_get_fsm_time_95 node_get_fsm_time_99
                    node_get_fsm_time_mean node_get_fsm_time_median node_put_fsm_time_mean
                    node_put_fsm_time_median node_put_fsm_time_95 node_put_fsm_time_99
                    node_put_fsm_time_100 node_get_fsm_objsize_mean node_get_fsm_objsize_median
                    node_get_fsm_objsize_95 node_get_fsm_objsize_99 node_get_fsm_objsize_100
                    node_get_fsm_siblings_mean node_get_fsm_siblings_median node_get_fsm_siblings_95
                    node_get_fsm_siblings_99 node_get_fsm_siblings_100}
    fqdn       = `hostname -f`.strip
    stats_host = get_stats_host(fqdn)
    stats_url  = "http://#{stats_host}:#{option(:stats_port)}/#{option(:stats_path)}"
    response   = Net::HTTP.get_response URI.parse(stats_url)
    raw_stats  = JSON.parse(response.body)
    result     = {}

    fsm_stats.each do |fsm_stat|
      result[fsm_stat] = raw_stats[fsm_stat] if raw_stats[fsm_stat]
    end
    
    report result
  end

  def get_stats_host(fqdn)
    if option(:use_dns_hostname) == "true"
      return Resolv::DNS.new("/etc/resolv.conf").getaddress(fqdn).to_s
    else
      return fqdn
    end
  end
end
