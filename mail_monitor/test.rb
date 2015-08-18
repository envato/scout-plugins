require 'test/unit'
require 'mocha/test_unit'
require File.expand_path('../mail_monitor.rb', __FILE__)

class Mail_monitorTest < Test::Unit::TestCase

  def setup
    @plugin = Mail_monitor.new(nil, {}, @options)
  end

  def test_successful_run_with_no_errors
    @plugin.stubs(:get_command_result).returns(File.read(File.dirname(__FILE__)+'/fixtures/empty.txt'))
    @plugin.stubs(:execute_command).returns(0)
    res = @plugin.run()
    assert(res[:errors].empty?, "res[:errors] is not empty")
  end

  def test_unable_to_find_mail_bin
    @plugin.stubs(:mail_bin_options).returns("blah")
    res = @plugin.run()
    assert(!res[:errors].empty?, "res[:errors] is not empty")
  end

  def test_failed_run_with_errors
    @plugin.stubs(:execute_command).returns(1)
    res = @plugin.run()
    assert(!res[:errors].empty?, "res[:errors] is empty")
  end

  def test_0_messages
    @plugin.stubs(:get_command_result).returns(File.read(File.dirname(__FILE__)+'/fixtures/empty.txt'))
    @plugin.stubs(:execute_command).returns(0)

    @plugin.run()
    assert_equal 0, @plugin.count
  end

  def test_more_than_0_messages
    @plugin.stubs(:get_command_result).returns(File.read(File.dirname(__FILE__)+'/fixtures/more_than_one_message.txt'))
    @plugin.stubs(:execute_command).returns(0)

    @plugin.run()
    assert_operator 0, :<,  @plugin.count
    #assert_equal 0, @plugin.count
  end
end
