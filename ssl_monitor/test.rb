#
# Scout Plugin: ssl_monitor
#
# Copyright 2013, Enrico Stahn <mail@enricostahn.com>
# Copyright 2013, Zanui <engineering@zanui.com.au>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require File.dirname(__FILE__) + '/../test_helper'
require File.dirname(__FILE__) + '/ssl_monitor'

class SslMonitorTest < Test::Unit::TestCase
  def setup
    @options = parse_defaults('ssl_monitor')
    @plugin = SslMonitor.new(nil, {}, @options)
  end

  def test_cmd_which_openssl
    @plugin.stubs(:`).with('which openssl').returns("/usr/local/bin/openssl\n")

    result = @plugin.cmd_which_openssl

    assert_not_nil result
    assert_equal   '/usr/local/bin/openssl', result
  end

  def test_cmd_certificate_end_date
    @plugin.stubs(:`).with('echo | openssl s_client -connect www.google.com:443 2> /dev/null | openssl x509 -noout -enddate').returns("notAfter=May 15 00:00:00 2014 GMT\n")

    result = @plugin.cmd_certificate_end_date('www.google.com', 443)

    assert_not_nil result
    assert_equal   'notAfter=May 15 00:00:00 2014 GMT', result
  end

  def test_openssl_bin_exists_false
    @plugin.stubs(:cmd_which_openssl).returns('')
    refute @plugin.openssl_bin_exists?
  end

  def test_openssl_bin_exists_true
    @plugin.stubs(:cmd_which_openssl).returns('/usr/local/bin/openssl')
    assert @plugin.openssl_bin_exists?
  end

  def test_fetch_certificate_end_date
    @plugin.stubs(:cmd_certificate_end_date).returns('notAfter=May 15 00:00:00 2014 GMT')
    assert_equal 'May 15 00:00:00 2014 GMT', @plugin.fetch_certificate_end_date('www.google.com', 443)
  end

  def test_fetch_certificate_end_date_nodate
    @plugin.stubs(:cmd_certificate_end_date).returns('foobar')
    assert_nil @plugin.fetch_certificate_end_date('www.google.com', 443)
  end

  def test_build_report_success
    @plugin.stubs(:openssl_bin_exists?).returns(true)
    @plugin.stubs(:fetch_certificate_end_date).returns("notAfter=May 15 00:00:00 2014 GMT\n")

    result = @plugin.run

    assert            result[:alerts].empty?, 'Alerts should be empty'
    assert            result[:errors].empty?, 'Errors should be empty'
    assert_equal 1,   result[:reports].size,  'Reports should have one entry'
    assert_equal 109, result[:reports].first[:days_left]
  end

  def test_build_report_no_openssl
    @plugin.stubs(:openssl_bin_exists?).returns(false)
    @plugin.stubs(:fetch_certificate_end_date).returns("notAfter=May 15 00:00:00 2014 GMT\n")

    result = @plugin.run

    assert result[:alerts].empty?, 'Alerts should be empty'
    assert_equal 1, result[:errors].size, 'Should contain no OpenSSL found'
  end

  def test_build_report_no_enddate
    @plugin.stubs(:openssl_bin_exists?).returns(true)
    @plugin.stubs(:fetch_certificate_end_date).returns(nil)

    result = @plugin.run

    assert result[:alerts].empty?, 'Alerts should be empty'
    assert_equal 1, result[:errors].size, 'Should contain no end date found'
  end
end
