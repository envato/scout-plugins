require 'rubygems'
require 'active_record'
require 'scout'
require 'rspec'
require File.dirname(__FILE__) + '/../monitor_delayed_jobs'

RAILS_ROOT = File.dirname(__FILE__) + '/rails'

FileUtils.rm_rf RAILS_ROOT + '/db/test.sqlite3'
ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => 'db/test.sqlite3'

class CreateDelayedJobs < ActiveRecord::Migration
  def self.up
    create_table "delayed_jobs", :force => true do |t|
      t.integer  "priority",   :default => 5
      t.integer  "attempts",   :default => 0
      t.text     "handler"
      t.text     "last_error"
      t.datetime "run_at"
      t.datetime "locked_at"
      t.datetime "failed_at"
      t.string   "locked_by"
      t.datetime "created_at"
      t.datetime "updated_at"
    end
  end
end
CreateDelayedJobs.up