# Validates that all members of the cluster report the same master

class ElasticsearchMasterStatus < Scout::Plugin
  OPTIONS = <<-EOS
    elasticsearch_port:
      default: 9200
      name: elasticsearch port
      notes: The port elasticsearch is running on
    elasticsearch_config:
      default: /etc/elasticsearch/elasticsearch.yml
      name: elasticsearch config
      notes: Full path to the ElasticSearch config yaml file
  EOS

  needs 'net/http', 'json', 'open-uri', 'yaml'

  def build_report
    if option(:elasticsearch_port).nil? || option(:elasticsearch_config).nil?
      return error("Please provide the port and config path", "The elasticsearch port and config path are required.\n\nelasticsearch Port: #{option(:elasticsearch_port)}\n\nelasticsearch Config: #{option(:elasticsearch_config)}")
    end

    masters = {}

    get_host_list.each do |host|
      master_status = get_master_from_node(host)
      masters[master_status[:host]] ||= 0
      masters[master_status[:host]]  += 1
    end

    report(:number_of_masters => masters.keys.size)

    if masters.keys.size > 1
      alert("Multiple ElasticSearch master nodes found! (#{masters})")
    end
  end

  def get_master_from_node(node)
    base_url = "http://#{node}:#{option(:elasticsearch_port)}/_cat/master"
    response = Net::HTTP.get(URI.parse(base_url)).chomp.split
    {
      :id   => response[0],
      :host => response[1],
      :ip   => response[2],
      :name => response[3]
    }
  rescue OpenURI::HTTPError
    error('Stats URL not found', "The generated stats URL (#{base_url}) was not found.")
  rescue SocketError
    error('Hostname is invalid', "The hostname of the generated stats URL (#{base_url}) was not found.")
  rescue Errno::ECONNREFUSED
    error('Unable to connect', "Please ensure the host and port are correct. Current URL: \n\n#{base_url}")
  end

  def get_host_list
    config = YAML.load_file(option(:elasticsearch_config))
    #require 'pry';binding.pry
    config.include?('discovery.zen.ping.unicast.hosts') ? config['discovery.zen.ping.unicast.hosts'].split(',') : []
  end

end

