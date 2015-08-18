class DiskInodeUsage < Scout::Plugin
  OPTIONS=<<-EOS
  command:
    name: df Command
    notes: The command used to display free inodes
    default: df -i
  filesystem:
    notes: The filesystem to check usage, if none specified, uses the first listed
  EOS

  DF_RE = /\A\s*(\S.*?)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*\z/

  def parse_file_systems(io, &line_handler)
    line_handler ||= lambda { |row| pp row }
    headers = nil
    row = ""
    io.each_line do |line|
      if headers.nil? and line =~ /\AFilesystem/
        headers = line.split(" ", 6)
      else
        row << line
        if row =~ DF_RE
          fields = $~.captures
          line_handler[headers ? Hash[*headers.zip(fields).flatten] : fields]
          row = ""
        end
      end
    end
  end

  def build_report
    ENV['lang'] = 'C' # forcing English for parsing
    df_command   = option('command') || 'df -i'
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
    
    # will be passed at the end to report to Scout
    report_data = Hash.new
    
    df_line.each do |name, value|
      report_data[name.downcase.strip.to_sym] = value.to_i
    end
    report(report_data)
  end
end
