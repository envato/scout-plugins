class GenericJsonUri < Scout::Plugin
  needs 'json', 'open-uri'
  
  OPTIONS=<<-EOS
    url: 
      name: URL
      notes: Full URL to a JSON end point you want to query. Can also be a local path to a file.
    username:
      notes: Username for basic http auth.
    password: 
      notes: Password for basic http auth.
  EOS
  
  def build_report
    if option(:username) && option(:password) 
      response = nil
      open option(:url), :http_basic_authentication => [option(:username), option(:password)] do |io|
        response = io.read
      end
    else
      response = open(option(:url)).read
    end
    obj = JSON.parse(response)
    
    if obj.is_a?(Array)
      out = {}
      obj.each do |item|
        out.merge!(item)
      end
      obj = out
    end
    
    report(obj)
  rescue Exception => e
    return error("Error getting JSON", e.message)
  end
  
end