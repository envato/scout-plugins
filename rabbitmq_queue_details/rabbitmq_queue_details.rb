# =================================================================================
# rabbitmq_overall
#
# Created by Erik Wickstrom on 2011-10-14.
# =================================================================================
class RabbitmqQueueDetails < Scout::Plugin
  needs 'json'
  needs 'net/http'
  needs 'cgi'

  OPTIONS=<<-EOS
    management_url:
        default: http://localhost:15672
        notes: The base URL of your RabbitMQ Management server. (Use port 55672 if you are using RabbitMQ older than 3.x)
    username:
        default: guest
    password:
        default: guest
        attributes: password
    queue:
        notes: The name of the queue to collect detailed metrics for
    vhost:
        notes: The virtual host containing the queue.
  EOS

  def build_report
    if option(:queue).nil?
      return error("Queue Required", "Specificy the queue you wish to monitor in the plugin settings.")
    end
    if option(:vhost).nil?
      return error("Vhost Required", "Specificy the vhost you wish to monitor in the plugin settings.")
    end

    queue = get_queue(option(:vhost), option(:queue))

    report(:messages                => value_or_zero(queue["messages"]),
           :messages_unacknowledged => value_or_zero(queue["messages_unacknowledged"]),
           :memory                  => value_or_zero(queue["memory"].to_f / (1024 * 1024)),
           :pending_acks            => value_or_zero(queue["backing_queue_status"]["pending_acks"]),
           :consumers               => value_or_zero(queue["consumers"]),
           :durable                 => queue["durable"] ? 1 : 0,
           :messages_ready          => value_or_zero(queue["messages_ready"]))

  rescue Errno::ECONNREFUSED
    error("Unable to connect to RabbitMQ Management server", "Please ensure the connection details are correct in the plugin settings.\n\nException: #{$!.message}\n\nBacktrace:\n#{$!.backtrace}")
  rescue SecurityError => e
    error("Server returned an error\nException: #{e.message}\n\nBacktrace:\n#{e.backtrace.join("\n")}")
  end

  def value_or_zero(val)
    val.nil? ? 0 : val
  end

  def get_queue(vhost, queue)
    url = "#{option('management_url').to_s.strip}/api/queues/#{CGI::escape(vhost)}/#{queue}/"
    data = query_api(url)
    raise SecurityError.new(data["reason"]) if data.kind_of?(Hash) && data.has_key?("error") && !data["error"].nil?
    data
  end

  def query_api(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == "https"
    req = Net::HTTP::Get.new(uri.path)
    req.basic_auth(option(:username), option(:password))
    response = http.request(req)
    data = response.body

    # we convert the returned JSON data to native Ruby
    # data structure - a hash
    JSON.parse(data)
  end
end
