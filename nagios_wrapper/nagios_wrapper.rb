#
# This plugin executes and parses return data from a nagios plugin
# Output is parsed according to http://nagios.sourceforge.net/docs/3_0/pluginapi.html as defined June 19, 2014
#
# * The status of the nagios plugin (OK/WARN/ERR/CRIT) is reported as 'status' using the plugins exit code
# * Only the first line of output from a nagios plugin is captured
# * Only the first 10 perfdata metrics are reported
#
class NagiosWrapper < Scout::Plugin

  OPTIONS=<<-EOS
  nagios_plugin_command:
    name: Full path of the nagios plugin to run
    notes: "Example: /usr/lib/nagios/plugins/check_http"
    default:
  nagios_plugin_args:
    name: Arguments to supply to the nagios_plugin_command
    notes: "Example: -H google.com -w 5 -c 10"
    default:
  EOS

  def build_report
    @nagios_plugin_command = option('nagios_plugin_command')
    @nagios_plugin_args = option('nagios_plugin_args')

    return if !sanity_check

    # We only support parsing the first line of nagios plugin output
    IO.popen("#{@nagios_plugin_command} #{@nagios_plugin_args}") {|io| @nagios_output = io.readlines[0] }
    
    # Use exit status integer for OK/WARN/ERROR/CRIT status
    plugin_status = $?.exitstatus

    data = parse_nagios_output(@nagios_output)
    report(data.merge({:status => plugin_status}))
  end

  def sanity_check
    if @nagios_plugin_command.nil?
      error("The nagios_plugin_command is not defined", "You must configure the full path of the nagios plugin command in nagios_plugin_command")
    elsif !File.exists?(@nagios_plugin_command)
      error("The nagios_plugin_command file does not exist", "The nagios_plugin_command file does not exist.")
    elsif !File.executable?(@nagios_plugin_command)
      error("Can not execute nagios_plugin_command", "The nagios_plugin_command file is not executable.")
    end
    data_for_server[:errors].any? ? false : true
  end

  def parse_nagios_output(output)
    text_field, perf_field = output.split('|',2)
    perf_data = {}
    if !perf_field.nil? && perf_field.strip!.length
      # Split the perf field
      # 1) on spaces
      # 2) up to the first 10 metrics
      # 3) split each "k=v;;;;" formatted metric into a key and value
      # 4) add the key to perf_data, and the digits from the value
      perf_field.split(" ")[0,10].inject(perf_data) {|r,e| k,v=e.split('=')[0,2]; r[k] = v.slice!(/^[\d.]*/).to_f if k && v; r}
    end

    #TODO - Allow ability to define regex captures of the text field numerical values as metrics
    text_data = {}

    return perf_data.merge(text_data)
  end
end