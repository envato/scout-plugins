$VERBOSE=false

class MonitorDelayedJobs < Scout::Plugin
  ONE_DAY    = 60 * 60 * 24

  OPTIONS=<<-EOS
  path_to_app:
    name: Full Path to the Rails Application
    notes: "The full path to the Rails application (ex: /var/www/apps/APP_NAME/current)."
  rails_env:
    name: Rails environment that should be used
    default: production
  EOS

  needs 'active_record', 'yaml', 'erb'

  # IMPORTANT! Requiring Rubygems is NOT a best practice. See http://scoutapp.com/info/creating_a_plugin#libraries
  # This plugin is an exception because we to subclass ActiveRecord::Base before the plugin's build_report method is run.
  require 'rubygems'
  require 'active_record'
  class DelayedJob < ActiveRecord::Base; end
  DelayedJob.default_timezone = :utc

  def build_report
    app_path = option(:path_to_app)

    # Ensure path to db config provided
    if !app_path or app_path.empty?
      return error("The path to the Rails Application wasn't provided.","Please provide the full path to the Rails Application (ie - /var/www/apps/APP_NAME/current)")
    end

    db_config_path = app_path + '/config/database.yml'

    if !File.exist?(db_config_path)
      return error("The database config file could not be found.", "The database config file could not be found at: #{db_config_path}. Please ensure the path to the Rails Application is correct.")
    end

    db_config = YAML::load(ERB.new(File.read(db_config_path)).result)
    ActiveRecord::Base.establish_connection(db_config[option(:rails_env)])

    report_hash = Hash.new

    # ALl jobs
    report_hash[:total]     = DelayedJob.count
    # Jobs that are currently being run by workers
    report_hash[:running]   = DelayedJob.count(:conditions => 'locked_at IS NOT NULL')
    # Jobs that are ready to run but haven't ever been run
    report_hash[:waiting]   = DelayedJob.count(:conditions => [ 'run_at <= ? AND locked_at IS NULL AND attempts = 0', Time.now.utc ])
    # Jobs that haven't ever been run but are not set to run until later
    report_hash[:scheduled] = DelayedJob.count(:conditions => [ 'run_at > ? AND locked_at IS NULL AND attempts = 0', Time.now.utc ])
    # Jobs that aren't running that have failed at least once
    report_hash[:failing]   = DelayedJob.count(:conditions => 'attempts > 0 AND failed_at IS NULL AND locked_at IS NULL')
    # Jobs that have permanently failed
    report_hash[:failed]    = DelayedJob.count(:conditions => 'failed_at IS NOT NULL')
    report_hash[:overdue] = DelayedJob.count(:conditions => ['attempts = 0 AND locked_at IS NULL and run_at < ?', Time.now.utc])
    report_hash[:erroring] = DelayedJob.count(conditions => 'last_error IS NOT NULL AND failed_at IS NULL')

    # The oldest job that hasn't yet been run, in minutes
    if oldest = DelayedJob.find(:first, :conditions => [ 'run_at <= ? AND locked_at IS NULL AND attempts = 0', Time.now.utc ], :order => :run_at)
      report_hash[:oldest] = (Time.now.utc - oldest.run_at) / 60
    else
      report_hash[:oldest] = 0
    end

    report(report_hash)
  end
end
