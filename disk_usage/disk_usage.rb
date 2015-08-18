class DiskUsage < Scout::Plugin

  OPTIONS=<<-EOS
  command:
    name: df Command
    notes: The command used to display free disk space
    default: df -h
  filesystem:
    notes: The filesystem to check usage, if none specified, uses the first listed
  EOS

  # the Disk Freespace RegEx
  DF_RE = /\A\s*(\S.*?)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*\z/

  # Parses the file systems lines according to the Regular Expression
  # DF_RE.
  # 
  # normal line ex:
  # /dev/disk0s2   233Gi   55Gi  177Gi    24%    /
  
  # multi-line ex:
  # /dev/mapper/VolGroup00-LogVol00
  #                        29G   25G  2.5G  92% /
  #
  def parse_file_systems(io, &line_handler)
    line_handler ||= lambda { |row| pp row }
    headers      =   nil

    row = ""
    io.each_line do |line|
      if headers.nil? and line =~ /\AFilesystem/
        headers = line.split(" ", 6)
      else
        row << line
        if row =~  DF_RE
          fields = $~.captures
          line_handler[headers ? Hash[*headers.zip(fields).flatten] : fields]
          row = ""
        end
      end
    end
  end
  
  # Ensures disk space metrics are in GB. Metrics that don't contain 'T,G,M,or K' are just
  # turned into integers.
   def clean_value(value)
     value = if value =~ /G/i
       value.to_f
     elsif value =~ /M/i
       (value.to_f/1024.to_f)
     elsif value =~ /K/i
       (value.to_f/1024.to_f/1024.to_f)
     elsif value =~ /T/i
       (value.to_f*1024.to_f)
     else
       value.to_f
     end
     ("%.1f" % [value]).to_f
   end

  def build_report
    ENV['LANG'] = 'C' # forcing English for parsing
    df_command   = option("command") || "df -h"
    df_output    = `#{df_command}`
          
    df_lines = []
    parse_file_systems(df_output) { |row| df_lines << row }
    
    # if the user specified a filesystem use that
    df_line = nil
    if option("filesystem")
      df_lines.each do |line|
        if line.has_value?(option("filesystem"))
          df_line = line
        end
      end
    end
    
    # else just use the first line
    df_line ||= df_lines.first
      
    # remove 'filesystem' and 'mounted on' if present - these don't change. 
    df_line.reject! { |name,value| ['filesystem','mounted on'].include?(name.downcase.gsub(/\n/,'')) }  
      
    assumed_capacity = df_line.find { |name,value| /capacity|use.*%|%.*use/ === name.downcase.gsub(/\n/,'') }
    df_line.delete(assumed_capacity.first)
    df_line['capacity'] = assumed_capacity.last
    
    # will be passed at the end to report to Scout
    report_data = Hash.new
      
    df_line.each do |name, value|
      report_data[name.downcase.strip.to_sym] = clean_value(value)
    end
    report(report_data)
  end
end
