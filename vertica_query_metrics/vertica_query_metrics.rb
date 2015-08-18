class VerticaQueryMetrics < Scout::Plugin
  OPTIONS=<<-EOS
  user:
    name: Vertica username
    notes: Specify the username to connect with
  password:
    name: Vertica password
    notes: Specify the password to connect with
    attributes: password
  database:
    name: Vertica database name
  EOS

	# Raised by #vertica_query when an error occurs.
  class VerticaConnectionError < Exception
  end

	def build_report
		@vertica_command   = option(:vertica_command) || '/opt/vertica/bin/vsql'
    res = vertica_query("SELECT * from query_metrics join current_session on current_session.node_name = query_metrics.node_name;")
    report(res.select { |k| %w(active_user_session_count active_system_session_count running_query_count).include?(k) })
    counter(:queries, res['executed_query_count'].to_i, :per => :second) if res['executed_query_count'] 
  end

	private

	def vertica_query(query)
		# SELECT * from query_metrics;' -A  docker dbadmin
    # node_name|active_user_session_count|active_system_session_count|total_user_session_count|total_system_session_count|total_active_session_count|total_session_count|running_query_count|executed_query_count
    # v_docker_node0001|1|2|21|1048|3|1069|1|8
    # {"node_name"=>"v_docker_node0001", "active_user_session_count"=>"1", "active_system_session_count"=>"2", "total_user_session_count"=>"49", "total_system_session_count"=>"3460", "total_active_session_count"=>"3", "total_session_count"=>"3509", "running_query_count"=>"1", "executed_query_count"=>"22"}
		result = `#{@vertica_command} -c "#{query}" -A #{option(:database)} -U #{option(:user)} #{option(:password).nil? ? '' : "-w #{option(:password)}"} 2>&1`
    if $?.success?
      output = {}
      keys, values = result.split(/\n/)
      keys = keys.split('|')
      values = values.split('|')
      keys.each_with_index { |key,i| output[key] = values[i]}
      output
    else
      raise VerticaConnectionError, result
    end
	end
end