class GearmanTask < Scout::Plugin
  require 'net/telnet'
  OPTIONS=<<-EOS
    task:
      name: Task
      notes: The Gearman task to monitor
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

    status.split("\n")[0...-1].map do |job|
      task, jobs, running, workers = job.split("\t")
      if task == option(:task)
        report(:jobs => jobs, :running => running, :workers => workers)
      end
    end
  end
end
