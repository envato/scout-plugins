require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../simple_process_check.rb', __FILE__)

class SimpleProcessCheckTest < Test::Unit::TestCase
  def setup
    @options = parse_defaults('simple_process_check')
    stub_process_call('ps -eo comm,args,pid', processes)
  end

  def test_reports_1_for_each_running_process
    plugin = SimpleProcessCheck.new(nil, {}, @options.merge({ :process_names => 'testprocess,otherprocess' }))
    response = plugin.run
    assert_equal([{ :processes_present => 2 }], response[:reports])
  end

  def test_reports_0_for_a_non_running_process
    plugin = SimpleProcessCheck.new(nil, {}, @options.merge({ :process_names => 'nonrunningprocess' }))
    response = plugin.run
    assert_equal([{ :processes_present => 0 }], response[:reports])
  end

  def test_reports_one_1_for_duplicate_matching_processes
    plugin = SimpleProcessCheck.new(nil, {}, @options.merge({ :process_names => 'testprocess' }))
    stub_process_call('ps -eo comm,args,pid', duplicate_processes)
    response = plugin.run
    assert_equal([{ :processes_present => 1 }], response[:reports])
  end

  def reports_a_process_with_matching_arguments
    plugin = SimpleProcessCheck.new(nil, {}, @options.merge({ :process_names => 'testprocess/arg_one,testprocess/nonmatching' }))
    response = plugin.run
    assert_equal([{ :processes_present => 1 }], response[:reports])
  end

  def test_alerts_when_the_process_count_changes
    plugin = SimpleProcessCheck.new(nil, {}, @options.merge({ :process_names => 'testprocess, otherprocess' }))
    plugin.run
    # second run only has one process reporting
    stub_process_call('ps -eo comm,args,pid', duplicate_processes)
    response = plugin.run
    assert_equal ["Process check: 2 of 2 processes are present", "Process check: 1 of 2 processes are present"], response[:alerts].map { |alert| alert[:subject] }
  end

  def test_does_not_count_the_current_running_process
    Process.stubs(:pid).returns(12345)
    plugin = SimpleProcessCheck.new(nil, {}, @options.merge({ :process_names => 'testprocess' }))
    response = plugin.run
    assert_equal([{ :processes_present => 0 }], response[:reports])
  end

  def test_downcases_process_info
    stub_process_call('ps -eo comm,args,pid', mixed_case_processes)
    plugin = SimpleProcessCheck.new(nil, {}, @options.merge({ :process_names => 'testprocess/arg_one' }))
    response = plugin.run
    assert_equal([{ :processes_present => 1 }], response[:reports])
  end

  def test_downcases_user_input
    plugin = SimpleProcessCheck.new(nil, {}, @options.merge({ :process_names => 'tEstpRoceSs/Arg_onE' }))
    response = plugin.run
    assert_equal([{ :processes_present => 1 }], response[:reports])
  end

  private

  def processes
    <<-EOS
testprocess     arg_one                     12345
otherprocess    arg_two                     23456
EOS
  end

  def duplicate_processes
    <<-EOS
testprocess     arg_one                     12345
testprocess     arg_two                     23456
EOS
  end

  def mixed_case_processes
    <<-EOS
TesTprOceSs     aRg_oNe                     12345
EOS
  end

  def stub_process_call(command, response)
    SimpleProcessCheck.any_instance.stubs(:`).with(command).returns(response)
    SimpleProcessCheck.any_instance.stubs(:ps_call_success?).returns({:success => true})
  end
end
