# Created by Sam Sinensky (http://github.com/samsinensky) at Code and Beats (http://codeandbeats.com/) 12/29/09
class SphinxMonitor < Scout::Plugin

  needs 'elif'
  needs 'time'

  OPTIONS=<<-EOS
  search_log_path:
    name: Searchd log path
    notes: This is the path to the log file
  query_log_path:
    name: Query log path
    notes: This is the path to the query log
  EOS

  def build_report

    #test command  = scout test sphinx_monitor.rb query_log_path=/Users/sam/Desktop/query.log.bak search_log_path=/Users/sam/Desktop/searchd.log.bak

    search_log_path = option(:search_log_path)

    query_log_path =  option(:query_log_path)

    unless search_log_path and not search_log_path.empty? and query_log_path and not query_log_path.empty?
      return error("Full paths to the searchd log and/or searchd query file(s) were not provided.", "Please provide the full paths to the log files in the plugin settings.")
    end

    last_run = memory(:last_request_time) || Time.now - 60
    # analyze last minute on first invocation

    #in seconds or amount/second
    report_data = {
            :query_rate => 0,
            :average_query_time => 0,
            :average_results_returned => 0,
            :index_rebuilds => 0,
            :average_time_per_rebuild => 0
    }

    #calculate the stats based on queries, rate, avg_time and average results returned

    #Load each line from the log in if it happened after the last request used in the previous report
    queries = 0
    total_query_time = 0
    total_results_returned = 0
    begin
      Elif.foreach(query_log_path) do |line|
        #extract the date form the line and make sure it occured after last_run
        line_data = parse_query_line(line)
        next if line_data.nil?
        if line_data.timestamp.to_f <= last_run.to_f
          break
        else
          queries+=1
          total_query_time += line_data.time_spent
          total_results_returned += line_data.results_returned
        end
      end

      if queries > 0
        # calculate the time btw runs in minutes
        interval = (Time.now-last_run)
        interval < 1 ? inteval = 1 : nil
        # if the interval is less than 1 second (may happen on initial run) set to 1 second
        interval = interval/60
        # convert to minutes
        interval = interval.to_f
        # determine the rate of queries in queries/min
        query_rate                             = queries / interval
        report_data[:query_rate]               = sprintf("%.2f", query_rate)
        report_data[:average_query_time]       = sprintf("%.4f", total_query_time/queries)
        report_data[:average_results_returned] = sprintf("%.4f", total_results_returned/queries)
      end
    rescue Errno::ENOENT => error
      return error("Unable to find the query log file", "Could not find the query log at the specified path: #{option(:query_log_path)}.")
    rescue Exception => error
      return error("Error while processing query log:\n#{error.class}: #{error.message}", error.backtrace.join("\n"))
    end

    #calculate the index rotation stats, only for index rotations that occur completely in the interval
    total_rotations = 0
    total_length_rotations = 0
    finish_time = nil
    begin
      Elif.foreach(search_log_path) do |line|
        line_data = parse_log_line(line)
        next if line_data.nil?
        if line_data.timestamp.to_f <= last_run.to_f
          break
        else
          if finish_time
            if line_data.step == :start
              total_rotations += 1
              total_length_rotations += finish_time.to_f - line_data.timestamp.to_f
              finish_time = nil
            end
          else
            finish_time = line_data.timestamp if line_data.step == :finish
          end
        end
      end

      if total_rotations > 0
        report_data[:index_rebuilds] = total_rotations
        report_data[:average_time_per_rebuild] = sprintf("%.4f", total_length_rotations/total_rotations)
      end
    rescue Errno::ENOENT => error
      return error("Unable to find the searchd log file", "Could not find the searchd log at the specified path: #{option(:query_log_path)}.")
    rescue Exception => error
      return error("Error while processing searchd log:\n#{error.class}: #{error.message}", error.backtrace.join("\n"))
    end
    # the time
    # should be fixed so that it stores the time of the last log entry from both logs
    remember(:last_request_time, Time.now)
    report(report_data)
  end

  private

  QueryData = Struct.new(:timestamp, :time_spent, :results_returned)

  LogData = Struct.new(:timestamp, :step)

  #based off of http://kobesearch.cpan.org/htdocs/Sphinx-Log-Parser/Sphinx/Log/Parser.pm.html
  def parse_query_line(line)
    time = line.match(/\[(.*?)\]/)
    if time
      time = time.captures.first
    else
      return nil
    end
    time_spent = line.match(/\]\s([\d\.]+).*?\[/)
    results_returned = line.match(/\s(\d+)\s\(/)

    if time_spent && results_returned
      time_spent = time_spent.captures.first
      results_returned = results_returned.captures.first
      return QueryData.new(Time.parse(time), time_spent.to_f, results_returned.to_i)
    else
      return nil
    end

  end

  def parse_log_line(line)
    time = line.match(/\[(.*?)\]/)
    if time
      time = time.captures.first
    else
      return nil
    end
    step = if line.match('rotating finished') || line.match('all indexes done')
             :finish
           elsif line.match('rotating indices') || line.match('caught SIGHUP')
             :start
           else
             :intermediate
           end
    begin
      LogData.new(Time.parse(time), step)
    rescue ArgumentError # time is not a time. the line is not formatted correctly
      return nil
    end
  end

end
