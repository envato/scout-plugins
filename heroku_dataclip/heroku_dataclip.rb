class HerokuDataclip < Scout::Plugin
  OPTIONS=<<-EOS
    dataclip_ids:
      default: ""
      notes: A comma-delimited list of dataclip IDs (the string of letters from the url) which return ONLY ONE FIELD AND ROW each
    max_staleness_in_minutes:
      default: "10"
      notes: The maximum time, in minutes, that a dataclip's data can fail to be retrieved before an error will be returned
  EOS

  def build_report
    dataclip_ids = option(:dataclip_ids)
    if dataclip_ids.nil? || dataclip_ids.empty? || dataclip_ids !~ /^[a-z,]+$/
      return error(
        'Invalid or missing option "dataclip_ids"',
        'The "dataclip_ids" option is required to be a comma-delimited list of dataclip IDs ' +
          '(the string of letters from the "dataclips.heroku.com" url) ' +
          'which return ONLY ONE FIELD AND ROW each ' +
          '(e.g. "SELECT COUNT(*) AS total_count FROM tablename;").'
      )
    end
    dataclip_ids = dataclip_ids.split(',')
    return error("Number of dataclip_ids exceeds maximum", "A maximum of 20 dataclip_ids are supported.") if dataclip_ids.length > 20
    dataclip_result_arrays = []
    dataclip_last_update_timestamps = {}

    # Request the dataclip data via curl
    begin
      Timeout.timeout(55) do
        dataclip_ids.each do |dataclip_id|
          curl_response = `curl -L https://dataclips.heroku.com/#{dataclip_id}.csv`.split
          if curl_response[1] && curl_response[1] =~ /^\d+$/ # second line must be a digit
            dataclip_result_arrays << curl_response
            dataclip_last_update_timestamps[dataclip_id] = Time.now.to_i
          end
        end
      end
    rescue Timeout::Error
      # don't let it run more than 55 seconds if a curl request hangs...
    end

    # remember the last update timestamp for each dataclip; return error if any are too old
    dataclip_ids.each do |dataclip_id|
      memory_key = :"last_update_#{dataclip_id}"
      last_update = dataclip_last_update_timestamps[dataclip_id] ||= memory(memory_key) || Time.now.to_i
      remember(memory_key, last_update)
    end

    # return an error if any are older than :max_staleness_in_minutes minutes
    stale_dataclip_update_timestamps = dataclip_last_update_timestamps.reject do |_, timestamp|
      Time.now.to_i - timestamp <= 60 * option(:max_staleness_in_minutes).to_i
    end

    unless stale_dataclip_update_timestamps.empty?
      return error(
        "Failing to retrieve #{stale_dataclip_update_timestamps.length} dataclip(s)",
        "The following dataclip(s) have not been successfully retrieved for more than #{option(:max_staleness_in_minutes)} " +
          "minutes: #{stale_dataclip_update_timestamps.keys.join(', ')}"
      )
    end

    dataclip_result_arrays.each do |dataclip_result_array|
      field_name = dataclip_result_array[0].to_sym
      field_value = dataclip_result_array[1]
      report(field_name => field_value)
    end
  end
end
