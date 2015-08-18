# Provide a comma-delimited list of process names (names only, no paths). This plugin checks that at least
# one instance of each named process is running, and alerts you if any of the processes have NO instances running.
# It alerts you again when one or more of the non-running processes is detected again.
#
# You can also check that a process name exists with a certain substring included in its arguments. For example, to
# check for two instances of node (one with "emailer" in its args, and one with "eventLogger" in its args), set this
# in process_names: node/emailer,node/eventLogger
#
# You can mix and match pure process_names and process_name/args. Note that the process names are always full string matches,
# and the args are always partial string matches.
#
# As long as you're using the default ps_command, this plugin will EXCLUDE the current scout ruby process from its results.
# In other words: if you're checking for `ruby` processes, this plugin will return 0, even though Scout IS running as a ruby
# process (assuming no other Ruby processes besides Scout are running).
class SimpleProcessCheck < Scout::Plugin

  OPTIONS=<<-EOS
    process_names:
      notes: "comma-delimited list of process names to monitor. Example: sshd,apache2,node/eventLogger. Not case sensitive."
    alert_total_processes_changes:
      notes: "Set to 'true' to generate an alert if the TOTAL number of processes changes."
      default: false
      attributes: advanced
    ps_command:
      label: ps command
      default: ps -eo comm,args,pid
      notes: Leave the default in most cases. If your output is getting truncated, consider specifying a width, e.g. "ps -eo comm,args:120,pid".
      attributes: advanced
  EOS

  def build_report
    process_names = option(:process_names).downcase
    if process_names.nil? or process_names == ""
      return error("Please specify the names of the processes you want to monitor. Example: sshd,apache2")
    end

    ps_output = `#{option(:ps_command)}`

    unless ps_call_success?
      return error("Couldn't use `ps` as expected.", error.message)
    end

    # This makes ps_output an array of two-element arrays (excluding current process):
    # [ ["smtpd", "smtpd -n smtp -t inet -u -c 14876"],
    #   ["proxymap", "proxymap -t unix -u 670"],
    #   ["apache2", "usr/sbin/apache2 -k start 24801"] ]
    ps_output=ps_output.downcase.split("\n").reject{|line| line =~ /\s+#{Process.pid}\z/ }.map{|line| line.split(/\s+/,2)}

    processes_to_watch = process_names.split(",").uniq
    process_counts = processes_to_watch.map do |p|
      name, arg_string = p.split("/").map{|s|s.strip}
      if arg_string
        res = ps_output.select{|row| process_name_match?(row[0],name) && row[1].include?(arg_string) }.size
      else
        res = ps_output.select{|row| process_name_match?(row[0],name) }.size
      end
      res
    end

    # The number of unique process names to watch from process_names
    uniq_processes=processes_to_watch.size
    uniq_processes_present = process_counts.select {|count| count > 0}.size

    # stored as memory(:num_processes) for backwards compatibility
    # unique_processes used to be called num_processes before adding a counter for total_processes on Sep 1 2014.
    previous_uniq_processes=memory(:num_processes)
    previous_uniq_processes_present=memory(:num_processes_present)


    # Get a total number of all unique process instances
    total_processes_present = process_counts.inject(0) {|total,num_instances| total += num_instances; total }
    # The total of all unique process instances found in the ps output
    previous_total_processes_present=memory(:total_processes_present)

    # alert if the number of processes monitored or the number of processes present has changed since last time
    if uniq_processes !=previous_uniq_processes || uniq_processes_present != previous_uniq_processes_present
      subject = "Process check: #{uniq_processes_present} of #{processes_to_watch.size} processes are present"
      body=""
      processes_to_watch.each_with_index do |process,index|
        body<<"#{index+1}) #{process} - #{process_counts[index]} instance(s) running  \n"
      end
      alert(subject,body)
    end

    # alert if the TOTAL number of instances across the unique process list has changed
    if option(:alert_total_processes_changes) == 'true' and total_processes_present != previous_total_processes_present
      subject = "Process check: #{total_processes_present} total processes are present. Previous total: #{previous_total_processes_present}"
      body = ""
      processes_to_watch.each_with_index do |process,index|
        body<<"#{index+1}) #{process} - #{process_counts[index]} instance(s) running  \n"
      end
      alert(subject,body)
    end

    remember :num_processes => uniq_processes
    remember :num_processes_present => uniq_processes_present

    remember :total_processes_present => total_processes_present

    report(:processes_present => uniq_processes_present, :total_processes_present => total_processes_present)
  end

  # True if a full match OR a match w/a colon appended to the name. Handles cases like:
  # sshd: ubuntu (so 'sshd' will match)
  def process_name_match?(output,name)
    output == name or output == "#{name.strip}:"
  end

  def ps_call_success?
    $?.success?
  end
end
