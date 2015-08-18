# Created by John Wood of Signal
class CouchDBDatabaseMonitoring < Scout::Plugin

  OPTIONS = <<-EOS
    couchdb_port:
      notes: The port that CouchDB is running on
      default: 5984
    couchdb_host:
      notes: The host that CouchDB is running on
      default: http://127.0.0.1
    database_name:
      notes: The name of the database you wish to get stats for
    couchdb_user:
      notes: The CouchDB http basic authentication user
      attributes: advanced
    couchdb_pwd:
      name: CouchDB Password
      notes: The CouchDB http basic authentication password
      attributes: advanced,password
  EOS

  needs 'net/http', 'json', 'open-uri'

  def build_report
    if option(:couchdb_host).nil? or option(:couchdb_port).nil? or option(:database_name).nil?
      return error("Please provide the host, port, and database name", "The Couch DB host, port, and database to monitor are required.\n\nCouch DB Host: #{option(:couchdb_host)}\n\nCouch DB Port: #{option(:couchdb_port)}\n\nDatabase Name: #{option(:database_name)}")
    end
    
    base_url = "#{option(:couchdb_host)}:#{option(:couchdb_port)}/"

    options = {}
    options[:http_basic_authentication] = [option(:couchdb_user), option(:couchdb_pwd)] if option(:couchdb_user)
    json_response=open(base_url + option(:database_name), options).read
    response = JSON.parse(json_response)
    report(:doc_count => response['doc_count'] || 0)
    report(:doc_del_count => response['doc_del_count'] || 0)
    report(:disk_size => b_to_mb(response['disk_size']) || 0)
    report(:purge_seq => response['purge_seq'] || 0)
    counter(:update_seq,(response['update_seq'] || 0).to_i,:per => :second)
  rescue OpenURI::HTTPError
    error("Stats URL not found","Please ensure the base url for Couch DB Stats is correct. Current URL: \n\n#{base_url}")
  rescue SocketError
    error("Hostname is invalid","Please ensure the Couch DB Host is correct - the host could not be found. Current URL: \n\n#{base_url}")
  end
  
  def b_to_mb(bytes)
    bytes && bytes.to_f / 1024 / 1024
  end
end