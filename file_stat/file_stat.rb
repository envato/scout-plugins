class FileStat < Scout::Plugin
  # Reports attributes from Ruby's File.stat(path)
  OPTIONS=<<-EOS
    path:
      label: Path
      notes: The full path to the file/directory/socket/fifo
    stats_list:
      label: Stats to report
      default: status,ftype,size,mode,uid,gid
      notes: 'A comma separated list of stats to report. Available stats: status, ctime, ctime_diff, mtime, mtime_diff, atime, atime_diff, blksize, blocks, dev, ftype, gid, ino, mode, nlink, setgid, setuid, size, sticky, uid or "all" for all stats'
      attributes: advanced
    alert_status_change:
      label: Alert on status change
      notes: Generate an alert when the "status" of the path changes
      default: "true"
      attributes: advanced
  EOS

  def build_report
    path = option(:path).to_s.strip
    return error("Path not configured.") if path.empty?
    stats_str = option(:stats_list).to_s.strip
    return error("Stats to report cannot be empty") if stats_str.empty?
    alert_status_change = option(:alert_status_change).to_s.downcase.strip == 'true' ? true : false

    default_status = {
      'status'      => -1,  # The file/direcoty/socket/fifo/etc status, -3 EACCES, -2 ENOENT, -1 UNKNOWN, 1 OK
      'ctime'       => -1,  # Change time for stat in UTC (the time directory information about the path was changed, not the path itself)
      'ctime_diff'  => -1,  # The ctime difference from now, in seconds
      'mtime'       => -1,  # Modification time in UTC (seconds since epoch)
      'mtime_diff'  => -1,  # The mtime difference from now, in seconds
      'atime'       => -1,  # Last access time for this path in UTC (seconds since epoch)
      'atime_diff'  => -1,  # The atime difference from now, in seconds
      'blksize'     => -1,  # Returns the native path system's block size. Will return nil on platforms that don't support this information.
      'blocks'      => -1,  # Returns the number of native path system blocks allocated for this path, or nil if the operating system doesn't support this feature.
      'dev'         => -1,  # Returns an integer representing the device on which stat resides.
      'ftype'       => -1,  # Identifies the type of stat. "unknown" -1, "file" 1 , "directory" 2, "characterSpecial" 3, "blockSpecial" 4, "fifo" 5, "link" 6, "socket" 7
      'gid'         => -1,  # Returns the numeric group id of the owner of stat.
      'ino'         => -1,  # Returns the inode number for stat.
      'mode'        => -1,  # Returns an integer representing the permission bits of stat. The meaning of the bits is platform dependent; on Unix systems, see stat(2).
      'nlink'       => -1,  # Returns the number of hard links to stat.
      'setgid'      => -1,  # Returns true if stat has the set-group-id permission bit set, false if it doesn't or if the operating system doesn't support this feature.
      'setuid'      => -1,  # Returns true if stat has the set-user-id permission bit set, false if it doesn't or if the operating system doesn't support this feature.
      'size'        => -1,  # Returns the size of stat in bytes.
      'sticky'      => -1,  # Returns true if stat has its sticky bit set, false if it doesn't or if the operating system doesn't support this feature.
      'uid'         => -1,  # Returns the numeric user id of the owner of stat.
    }.freeze

    status_codes = {'Errno::EACCES'    => -3,
                    'Errno::ENOENT'    => -2,
                    'UNKNOWN'          => -1,
                    'OK'               =>  1 }
    status_codes.default = -1

    ftype_codes = {'unknown'          => -1,
                   'file'             =>  1,
                   'directory'        =>  2,
                   'characterSpecial' =>  3,
                   'blockSpecial'     =>  4,
                   'fifo'             =>  5,
                   'link'             =>  6,
                   'socket'           =>  7 }
    ftype_codes.default = -1

    stats_list = []
    invalid_stat_names = []
    stats_str.split(',').each do |stat|
      stat_name = stat.strip.downcase.delete('?')
      if stat_name == "all"
        stats_list = default_status.keys
        break
      elsif default_status.has_key?(stat_name)
        stats_list << stat_name
      else
        invalid_stat_names << stat_name
      end
    end

    # Always report status
    stats_list << 'status'

    # Should never happen since we always report status - cannot proceed
    return error('No valid stats in stats_list!') if stats_list.empty?

    if invalid_stat_names.any?
      previous_invalid_stat_names = memory(:invalid_stat_names)
      # Proceed, but report invalid stat_names detected
      if invalid_stat_names != previous_invalid_stat_names
        error(:subject => 'Invalid stat name(s) detected', :body => "Invalid stat name(s) detected: '#{invalid_stat_names.join(',')}'")
        remember(:invalid_stat_names)
      end
    end

    previous_status = memory(:file_status) || default_status.dup

    # Initialize everything to defaults
    file_status = default_status.dup

    # Remove all keys NOT included in stats_list. Do this now so if we cannot stat the 
    # path (permission denied, path does not exist) we will return the defaults. This 
    # allows triggers to know when something has changed and they can alert on it.
    file_status = file_status.inject({}){|m, (k,v)| m[k] = v if stats_list.include?(k); m }

    fstat = nil
    begin
      fstat = File.stat(path)
    rescue Errno::EACCES, Errno::ENOENT => e
      file_status['status'] = status_codes[e.class.to_s]
      if alert_status_change and file_status['status'] != previous_status['status']
        alert("Cannot stat path: #{e.message}")
      end
      remember :file_status => file_status
      return report(file_status)
    end

    file_status['status'] = status_codes['OK']
    if file_status['status'] != previous_status['status']
      alert(:subject => "Status changed for #{path}", :body => "Current Status: #{file_status['status']} - Previous Status: #{previous_status['status']}") if alert_status_change
    end
    
    # stat methods that return DateTime objects
    %w(atime mtime ctime).each do |meth|
      next unless stats_list.include?(meth)
      if ret = fstat.send(meth.to_sym)
        file_status[meth] = ret.utc.to_i
        file_status["#{meth}_diff"] = Time.now.utc.to_i - file_status[meth] # Files with timestamps in the future will be negative.
      end
    end

    # stat methods that return nil, integers or fixnums
    %w(blksize blocks dev gid ino mode nlink size uid).each do |meth|
      next unless stats_list.include?(meth)
      if ret = fstat.send(meth.to_sym)
        # if not nil, set the ret value on file_status[meth]
        file_status[meth] = ret.to_i
      end
    end

    # stat methods that return true or false
    %w(setgid? setuid? sticky?).each do |meth|
      next unless stats_list.include?(meth.delete('?'))
      ret = fstat.send(meth.to_sym)
      file_status["#{meth.delete('?')}"] = ret ? 1 : 0 # 1 for true, 0 for false
    end

    # Convert the ftype string into integer code
    file_status['ftype'] = ftype_codes["#{fstat.ftype}"] if stats_list.include?('ftype')

    remember :file_status => file_status
    return report(file_status)
  end
end
