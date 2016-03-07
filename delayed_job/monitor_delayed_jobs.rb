$VERBOSE=false

class MonitorDelayedJobs < Scout::Plugin
  OPTIONS=<<-OPTIONS_DESCRIPTION_YAML
  path_to_app:
    name: Full Path to the Rails Application
    notes: "The full path to the Rails application (ex: /var/www/apps/APP_NAME/current)."
  rails_env:
    name: Rails environment that should be used
    default: production
  queue_name:
    name: Queue Name
    notes: 'If specified, only gather the metrics for jobs in this specific queue name. When nil, aggregate metrics from all queues, unless exclude_queue_name is specified. Default is nil'
  exclude_queue_name:
    name: Exclude Queue Name
    notes: 'If specified, do not gather the metrics for jobs in this specific queue name. When nil, aggregate metrics from all queues, unless queue_name specified. Default is nil.'
  custom_loader:
    name: 'Custom Loader'
    notes: 'If specified, requires the specified file (assuming its in the path_to_app) and attempts to call a Class Method "load!". This is useful for executing arbitrary code from within the plugin :). Specifically where your database.yml ERB might require classes defined that return values.'
  OPTIONS_DESCRIPTION_YAML

  needs 'active_record', 'active_support', 'yaml', 'erb'

  require 'thread'
  # IMPORTANT! Requiring Rubygems is NOT a best practice. See http://scoutapp.com/info/creating_a_plugin#libraries
  # This plugin is an exception because we to subclass ActiveRecord::Base before the plugin's build_report method is run.
  require 'rubygems'
  require 'active_record'

  class DbConnError < StandardError; end

  class DelayedJob < ActiveRecord::Base
    self.default_timezone = :utc

    def self.custom_count(query_conditions)
      if new_activerecord_version?
        # ActiveRecord >= 3.x uses AREL query format
        where(query_conditions).count
      else
        # ActiveRecord 2.x compatible
        count(:all, :conditions => query_conditions)
      end
    end

    def self.custom_select(select_clause, query_conditions)
      if new_activerecord_version?
        # ActiveRecord >= 3.x uses AREL query format
        select(select_clause).where(query_conditions)
      else
        # ActiveRecord 2.x compatible
        find_by_sql [
          "SELECT #{select_clause} FROM #{DelayedJob.table_name} WHERE #{query_conditions.shift}",
          *query_conditions
        ]
      end
    end

    def self.new_activerecord_version?
      DelayedJob.respond_to?(:where)
    end
  end


  DELAYED_JOB_QUERIES = {
    :total => {
      :sql => 'id IS NOT NULL'
    },
    # Jobs that are currently being run by workers
    :running => {
      :sql => 'locked_at IS NOT NULL AND failed_at IS NULL'
    },
    # Jobs that are ready to run but haven't ever been run
    :waiting => {
      :sql => 'run_at <= ? AND locked_at IS NULL AND attempts = 0', :args => [ Time.now.utc ]
    },
    # Jobs that haven't ever been run but are not set to run until later
    :scheduled => {
      :sql => 'run_at > ? AND locked_at IS NULL AND attempts = 0', :args => [ Time.now.utc ]
    },
    # Jobs that aren't running that have failed at least once
    :failing => {
      :sql => 'attempts > 0 AND failed_at IS NULL AND locked_at IS NULL'
    },
    # Jobs that have permanently failed
    :failed => {
      :sql => 'failed_at IS NOT NULL'
    },
    # The oldest job that hasn't yet been run, in minutes
    :oldest => {
      :sql => 'run_at <= ? AND locked_at IS NULL AND attempts = 0', :args => [ Time.now.utc ],
      :select => 'MIN(run_at) as run_at',
      :calc => Proc.new do |query|
        begin
          ((Time.now.utc - query.first.run_at) / 60).floor
        rescue
          0
        end
      end
    }
  }.freeze

  def build_report
    custom_loader
    setup_database_connection

    report_hash = Hash.new

    DELAYED_JOB_QUERIES.each do |name, criteria|
      sql = criteria[:sql] + queue_filter_sql
      args = criteria.fetch(:args, []).dup
      args << queue_filter_params if queue_filter_params
      query_conditions = args.unshift(sql)

      report_hash[name] = if criteria[:select]
                            criteria.fetch(:calc, Proc.new {|x| x}).call(
                              DelayedJob.custom_select(criteria[:select], query_conditions)
                            )
                          else
                            DelayedJob.custom_count(query_conditions)
                          end


    end

    report(report_hash)

  rescue DbConnError => err
    error("ERROR: connecting to database", err.message)
  end

private
  def setup_database_connection
    app_path = option(:path_to_app)

    # Ensure path to db config provided
    if !app_path or app_path.empty?
      raise DbConnError.new(
        "The path to the Rails Application wasn't provided.
        Please provide the full path to the Rails Application (ie - /var/www/apps/APP_NAME/current)"
      )
    end

    db_config_path = app_path + '/config/database.yml'

    unless File.exist?(db_config_path)
      raise DbConnError.new(
        "The database config file could not be found at: #{db_config_path}
        Please ensure the path to the Rails Application is correct."
      )
    end

    db_config = YAML::load(ERB.new(File.read(db_config_path)).result)
    ActiveRecord::Base.establish_connection(db_config[option(:rails_env)])

    if "production" != option(:rails_env)
      # log to STDOUT except in production
      if DelayedJob.new_activerecord_version?
        ActiveRecord::Base.logger = Logger.new(STDOUT)
      else
        ActiveRecord::Base.connection.instance_variable_set :@logger, Logger.new(STDOUT)
      end
    end
  end

  def custom_loader
    app_path = option(:path_to_app)
    if option(:custom_loader)
      custom_loader = File.join(app_path, option(:custom_loader))

      require custom_loader
      klass_file = File.basename(custom_loader)
      if klass_match = klass_file.match(/(.*)(\.\w+$)/)
        klass = camelize(klass_match[1])
      else
        klass = camelize(klass_file)
      end

      Kernel.const_get(klass).send("load!", option(:rails_env))
    end
  end

  def queue_filter_params
    @queue_filter_params ||= option(:queue_name) || option(:exclude_queue_name)
  end

  def queue_filter_sql
    @queue_filter_sql ||= if option(:queue_name)
                            ' AND queue = ?'
                          elsif option(:exclude_queue_name)
                            ' AND ( queue <> ? or queue IS NULL )'
                          else
                            ''
                          end
  end

  # Taken from http://infovore.org/archives/2006/08/11/writing-your-own-camelizer-in-ruby/
  def camelize(str)
    str.split('_').map {|w| w.capitalize}.join
  end
end
