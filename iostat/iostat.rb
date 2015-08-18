class Iostat < Scout::Plugin

  OPTIONS=<<-EOS
  device:
    name: Device
    notes: The device to check, eg 'sda1'. If not specified, uses the device mounted at '/'
  EOS

  def build_report
    @default_device_used = false
    # determine the device, either from the passed option or by parsing `mount`
    device = get_symlinked_device_name(option('device')) || option('device') || default_device
    stats = iostat(device)
    error("Device not found: #{device} -- check your plugin settings.",
          "FYI, mount returns:\n#{`mount`}") and return if !stats

    counter(:rps,   stats['rio'],        :per => :second)
    counter(:wps,   stats['wio'],        :per => :second)
    counter(:rkbps, stats['rsect'] / 2,  :per => :second)
    counter(:wkbps, stats['wsect'] / 2,  :per => :second)
    counter(:util,  stats['use'] / 10.0, :per => :second)
    # Not 100% sure that average queue length is present on all distros.
    if stats['aveq']
      counter(:aveq,  stats['aveq'], :per => :second)
    end

    if old = memory("#{device}_stats")
      ios = (stats['rio'] - old['rio']) + (stats['wio']  - old['wio'])

      if ios > 0
        await = ((stats['ruse'] - old['ruse']) + (stats['wuse'] - old['wuse'])).abs / ios.to_f

        report(:await => await)
      end
    end

    remember("#{device}_stats" => stats)
  end
  
  private
  COLUMNS = %w(major minor name rio rmerge rsect ruse wio wmerge wsect wuse running use aveq)

  # If a full path to a device is used, check to see if the device is a symlink to the real device
  # E.g.  /dev/mapper/some_lvm-volume is really dm-3
  def get_symlinked_device_name(device)
    return nil unless device
    real_device = nil
    begin
      if device.start_with?('/') and File.lstat(device).symlink?
        require 'pathname'
        real_device = Pathname.new(device).realpath.basename.to_s
      end
    rescue
      # do nothing
    end
    return real_device
  end

  # Returns the device mounted at "/"
  def default_device
    @default_device_used = true
    `mount`.split("\n").grep(/ \/ /)[0].split[0]
  end

  # Returns the /proc/diskstats line associated with device name +dev+. Logic:
  #
  # * If an exact match of the specified device is found, returns it. 
  # * If there isn't an exact match but there are /proc/diskstats lines that are included in +dev+, 
  #   returns the first matching line. This is needed as the mount output used to find the default device doesn't always 
  #   match /proc/diskstats output.
  # * If there are no matches but an LVM is used, returns the line matching "dm-0". 
  def iostat(dev)
    # if a LVM is used, `mount` output doesn't map to `/diskstats`. In this case, use dm-0 as the default device.
    lvm = nil
    retried = false
    possible_devices = []
    begin
      %x(cat /proc/diskstats).split(/\n/).each do |line|
        entry = Hash[*COLUMNS.zip(line.strip.split(/\s+/).collect { |v| Integer(v) rescue v }).flatten]
        possible_devices << entry if dev.include?(entry['name'])
        lvm = entry if (@default_device_used and 'dm-0'.include?(entry['name']))
      end
    rescue Errno::EPIPE
      if retried
        raise
      else
        retried = true
        retry
      end
    end
    found_device = possible_devices.find { |entry| dev == entry['name'] } || possible_devices.first
    return found_device || lvm
  end
end
