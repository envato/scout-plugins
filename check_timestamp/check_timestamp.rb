class CheckTimestamp < Scout::Plugin

  OPTIONS=<<-EOS
    path:
      name: path
      notes: path to the file which will have its timestamp checked
      default: /fully/qualified/path/to/your/file
  EOS

  def build_report
    begin
      path = option(:path)
      timestamp = File.new(path).mtime
      current_time = Time.now
      difference = (current_time - timestamp).round.to_f
      report(:difference => difference)
    rescue Exception => e
      error(:subject => 'Error running Check Timestamp plugin', :body => e)
    end
  end
end
