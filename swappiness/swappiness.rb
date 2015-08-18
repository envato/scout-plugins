# 
# Created by Eric Lindvall <eric@sevenscale.com>
#
# Name provided by Jesse Newland <jesse@railsmachine.com>
#

class Swappiness < Scout::Plugin
  def build_report
    if vmstat?
      counter('Swap-ins',    vmstat['pswpin'],  :per => :second)
      counter('Swap-outs',   vmstat['pswpout'], :per => :second)
      counter('Page-ins',    vmstat['pgpgin'],  :per => :second)
      counter('Page-outs',   vmstat['pgpgout'], :per => :second)
      counter('Page Faults', vmstat['pgfault'], :per => :second)
    else
      error("Unable to fetch metrics","/proc/vmstat doesn't exist on this system.")
    end
  rescue Exception => e
    error("An error occurred profiling the memory:\n\n#{e.class}: #{e.message}\n\t#{e.backtrace.join("\n\t")}")
  end

  def vmstat?
    File.exists?('/proc/vmstat')
  end

  def vmstat
    @vmstat ||= begin
      hash = {}
      %x(cat /proc/vmstat).split(/\n/).each do |line|
        _, key, value = *line.match(/^(\w+)\s+(\d+)/)
        hash[key] = value.to_i
      end
      hash
    end
  end
end