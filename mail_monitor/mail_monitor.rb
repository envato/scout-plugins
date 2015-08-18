#!/usr/bin/env ruby
# Purpose:  Count the messages in the mail queue and report on them
require 'scout'

#Below this comment is what needs to be uploaded to scout plugins via web
class Mail_monitor < Scout::Plugin
  attr_accessor :count, :mail_bin_options

  #Find the mail binary to show the message queue
  def mail_bin()
    @mail_bin_options = [ 'sendmail', 'mailq' ] #sendmail set first as preference, optional

    bin = nil

    #set mail bin if found
    @mail_bin_options.each do |b|
      bin = `which #{b}`.chomp if $?.to_i == 0
    end

    #Error out if no mail bin found or set appropiate switch for sendmail
    if bin.nil?
      error("mail binary cannot be found for #{@mail_bin_options}")
    elsif bin =~ /sendmail/
      bin = "#{bin} -bp"
    end

    return "#{bin}"
  end

  #execute mail command
  def execute_command(mail_bin)
    begin
      @command_result = `#{mail_bin} 2> /dev/null`
      exit_code = $?.to_i
      #command_return_code = $?.to_i

    rescue StandardError=>e
      error("#{e}")
      exit
    end

    return exit_code
  end

  def get_command_result()
    return @command_result
  end

  def parse_output(exit_code)

    @count = 0

    #if the return code is anything other than 0 it should fail
    if exit_code.to_i != 0
      error("Bad exit code from '#{mail_bin}'")

    #if the return code is 0, proceed with parsing the output
    elsif exit_code.to_i == 0
      #split each line of output into an array and then iterate
      get_command_result.split(/\n/).each do |line|
        #If there are no messages, report 0
        if "#{line}" =~ /Mail queue is empty/
          @count = 0

        #Look for timestamp in message queue ex. Apr 22 10:00:00
        elsif "#{line}" =~ /\w{3}\s\d\d?\s\d{2}:\d{2}:\d{2}/i
          #depending on how many messages are found, count them
          @count += 1
        end
      end
    end
  end

  def command_exit_code()
    return execute_command(mail_bin())
  end

  def build_report()
    #@command_exit_code = execute_command(mail_bin())
    parse_output(execute_command(mail_bin()))

    #Report back to scout in minute intervals
    counter(:messages, @count, :per => :minute)
  end
end
