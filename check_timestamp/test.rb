require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../check_timestamp.rb', __FILE__)

class CheckTimestampTest < Test::Unit::TestCase
  def test_difference
    current_time = Time.now
    file_time = current_time - 120
    Timecop.freeze(current_time) do
      File.any_instance.stubs(:mtime).returns(file_time)
      plugin = CheckTimestamp.new(nil, {}, @options.merge(path: 'check_timestamp/check_timestamp.rb'))
      res = plugin.run
      assert_equal 120, res[:reports].first[:difference]
    end
  end
end
