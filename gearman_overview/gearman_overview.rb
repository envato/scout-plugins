class GearmanOverview < Scout::Plugin
  needs 'net/telnet'
  OPTIONS=<<-EOS
    host:
      name: Host
      default: localhost
      notes: Hostname or IP address of the Gearman job server
    port:
      name: Port
      default: 4730
  EOS
  def build_report
    telnet = Net::Telnet::new("Host" => option(:host), "Port" => option(:port))
    status = telnet.cmd("String" => "status", "Match" => /\n./)
    counts = { :jobs => 0, :running => 0, :workers => 0}
    status.split("\n")[0...-1].map do |job|
      task, jobs, running, workers = job.split("\t")
      counts[:jobs] += jobs.to_i
      counts[:running] += running.to_i
      counts[:workers] += workers.to_i
    end
    report(counts)
  end
end
