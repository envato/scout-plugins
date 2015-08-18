#
# Modified load_averages to show load/processor, as this is a more accurate
# measurement of CPU utilization.
#
# Requires /proc/cpuinfo
#
class LoadAverages < Scout::Plugin

  OPTIONS=<<-EOS
    num_processors:
      name: Number of Processors
      notes: For calculating CPU load. If left blank, autodetects through /proc/cpuinfo
      default: 1
  EOS

   def build_report
     ENV['LANG'] = 'C' # forcing english for parsing
     if `uptime` =~ /load average(s*): ([\d.]+)(,*) ([\d.]+)(,*) ([\d.]+)\Z/
       report :last_minute          => $2.to_f/num_processors,
              :last_five_minutes    => $4.to_f/num_processors,
              :last_fifteen_minutes => $6.to_f/num_processors
     else
       raise "Couldn't use `uptime` as expected."
     end
  rescue Exception
    error "Error determining load", $!.message
  end

  def num_processors
    # first, check if the options provided is > 0. So leave the options blank to auto-detect
    processors = option('num_processors').to_i
    return processors if processors > 0

    # otherwise, pull it from memory
    processors = memory(:processors)

    # if we didn't get it from memory, try to auto-detect through /proc/cpuinfo
    unless processors && processors > 0
      if `cat /proc/cpuinfo | grep 'model name' | wc -l` =~ /(\d+)/
        processors = $1.to_i
      else
        raise "Couldn't use /proc/cpuinfo as expected."
      end
      raise "Couldn't use /proc/cpuinfo as expected." unless processors > 0
    end
    remember(:processors, processors)
    return processors
  end

end
