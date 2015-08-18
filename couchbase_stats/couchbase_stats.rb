# Reports stats on the couchbase node in the 
# Couchbase cluster, including if the node 
# is healthy and active in the cluster.
#
# Created by Michael Biven (michael@biven.org)
#

class CouchbaseStats < Scout::Plugin
require 'json'

  OPTIONS = <<-EOS
  client_host:
    name: Host
    notes: "Couchbase hostname (or IP address)"
    default: localhost
  client_port:
    name: Port
    notes: "Couchbase port."
    default: 8091
  client_password:
    name: Password
    notes: "Couchbase password."
    default: ""
    attributes: password
  client_username:
    name: Username
    default: "ops"
  cli_path:
    name: Path
    notes: Full path to couchbase-cli
    default: "/opt/couchbase/bin/couchbase-cli"
  EOS

  def build_report
    couchnode = `#{option(:cli_path)} server-info -c #{option(:client_host)}:#{option(:client_port)} -u #{option(:client_username)} -p #{option(:client_password)}`
    couchnode = JSON.parse(couchnode)
    node_health = couchnode['status']
    node_status = couchnode['clusterMembership']

    if node_health.include?('healthy')
      report('health' => 1)
    else
      report('health' => 0)
    end

    if node_status.include?('active')
      report('status' => 1)
    else
      report('status' => 0)
    end
  end
end
