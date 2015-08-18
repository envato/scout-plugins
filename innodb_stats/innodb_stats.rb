class InnodbStats < Scout::Plugin
  OPTIONS=<<-EOS
    mysql_command:
      default: sudo mysql
      name: Command to run the mysql client 
  EOS

  KILOBYTE = 1024.00
  MEGABYTE = 1048576.00

  def build_report
    @mysql_command = option(:mysql_command) || "sudo mysql"
    innodb_status = mysql_query("show status like 'Innodb%'")
    innodb_variables = mysql_query("show variables like 'Innodb%'")
    
    pool_size = innodb_variables[:innodb_buffer_pool_size].to_i
    pages_free = innodb_status[:innodb_buffer_pool_pages_free].to_i
    page_size = innodb_status[:innodb_page_size].to_i
    
    if pages_free && page_size > 0
      pool_capacity = 100.0 - (((pages_free * page_size)/pool_size.to_f)*100)
    else
      pool_capacity = 0.0
    end
    
    writes = innodb_status[:innodb_data_writes].to_i
    reads = innodb_status[:innodb_data_reads].to_i
    
    if writes > 0
      write_percentage = (writes.to_f/(writes+reads))*100.00
    else
      write_percentage = 0
    end
    
    counter(:writes, writes, :per => :minute)
    counter(:reads, reads, :per => :minute)
    
    if pool_size > 0
      pool_size = pool_size / MEGABYTE
    end
    
    if page_size > 0
      page_size = page_size / KILOBYTE
    end
    
    report(
      :buffer_pool_size => pool_size,
      :buffer_pool_capacity => pool_capacity,
      :buffer_pool_pages_free => pages_free,
      :page_size => page_size,
      :write_percentage => write_percentage
    )

  end

  def mysql_query(query)
    result = `#{@mysql_command} -e "#{query}"`
    if $?.success?
      output = {}
      result.split(/\n/).each do |line|
         row = line.split(/\t/)
         output[row.first.downcase.to_sym] = row.last
      end
      output
    else
      raise MysqlConnectionError, result
    end
  end

  class MysqlConnectionError < Exception
  end
end
