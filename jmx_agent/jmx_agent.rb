#
# Copyright 2011 Pulse Energy Inc.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#    http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
# A Scout Plugin for reading JMX values.
#
# Requires: Java SDK and jmxterm [http://wiki.cyclopsgroup.org/jmxterm]
#
class JmxAgent < Scout::Plugin
  OPTIONS=<<-EOS
    jmxterm_uberjar:
      name: jmxterm uberjar File
      notes: Absolute file name of the jmxterm uberjar.
    
    jvm_pid_file:
      name: JVM PID File
      notes: File from which the PID of the JVM process can be read.
             Optional. If absent, mbean_server_url must be configured.
      
    mbean_server_url:
      name: MBean Server URL
      notes: The URL can be <host>:<port> or full service URL.
             Optional. If absent, jvm_pid_file must be configured.
             
    mbeans_attributes:
      name: MBean and Attributes Names
      default: HeapMemoryUsage,NonHeapMemoryUsage@java.lang:type=Memory
      notes: A pipe-delimited list of comma separated attribute names @ MBean name.
      For example: HeapMemoryUsage,NonHeapMemoryUsage@java.lang:type=Memory|Name@java.lang:type=Runtime

    java_command:
      name: Java Command
      default: java
      notes: The Java command to execute. Can be used to specify the
             full path to Java or to execute under sudo or other wrappers.
  EOS
  
  def to_float?(value)
    Float(value)
  rescue
    value
  end
  
  def parse_attribute_line(line)
    s = line.split(/[=;]/)
    {:name => s[0].strip, :value => to_float?(s[1].strip)}
  end
  
  def read_mbean(jmx_cmd, mbean, attributes)
    values = {}
    command = "echo get -b #{mbean} #{attributes} | #{jmx_cmd}"
    result = "not executed yet"
    begin
      result = `#{command} 2>&1`

      if result.match(/No such PID (\d+)/)
        error("Java PID #{$1} is invalid", "Command: #{command}\n\nResult: #{result}")
        return {}
      end

      attribute = nil
      composite = false

      result.each_line do |line|
        next if line.strip.empty?

        if composite then
          if (line.strip.end_with?('};')) then
            composite = false
          else
            p = parse_attribute_line(line)
            values["#{attribute}.#{p[:name]}"] = p[:value]
          end
        else
          p = parse_attribute_line(line)
          attribute = p[:name]
          if (p[:value]  == '{') then
            composite = true
          else
            values[attribute] = p[:value]
          end
        end
      end
    rescue => e
      error("Error running JMX command", "Command: #{command}\n\nResult: #{result}\n\nException: #{e.message}\n\nBacktrace: #{e.backtrace}")
    end
    values
  end

  def build_report
    jvm_pid_file = option(:jvm_pid_file)
    mbean_server_location = option(:mbean_server_url)

    if jvm_pid_file and !jvm_pid_file.empty? then
      jvm_pid = File.open(jvm_pid_file).readline.strip
      mbean_server_location = jvm_pid
    end

    if mbean_server_location.nil? or mbean_server_location.empty?
      return error("A a JMX PID or an MBean Server Url is required",
           "No MBean server location configured: no PID file nor server URL")
    end

    mbeans_attributes = option(:mbeans_attributes)
    return error("No MBeans and Attributes Names defined") if mbeans_attributes.nil? or mbeans_attributes.empty?

    java_command = option(:java_command)
    return error("No Java Command defined") if java_command.nil? or java_command.empty?

    jmxterm_uberjar = option(:jmxterm_uberjar)
    return error("No jmxterm uberjar file defined") if jmxterm_uberjar.nil? or jmxterm_uberjar.empty?

    jmx_cmd = "#{java_command} -jar #{jmxterm_uberjar} -l #{mbean_server_location} -n -v silent"

    # validate JVM connectivity
    read_mbean(jmx_cmd, 'java.lang:type=Runtime', 'Name')
    return if errors.any?
    
    report_content = {}
    
    # query configured mbeans
    mbeans_attributes.split('|').each do |mbean_attributes|
      s = mbean_attributes.split('@')
      raise "Invalid MBean attributes configuration" unless s.size == 2
      mbean = s[1]
      attributes = s[0].gsub(',', ' ')
      res = read_mbean(jmx_cmd, mbean, attributes)
      next if res.empty?
      report_content.merge!(res)
    end

    report(report_content)
  end
end