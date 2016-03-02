require File.dirname(__FILE__) + '/spec_helper'

describe MonitorDelayedJobs, 'build_report' do
  
  def use_transactional_fixtures
    false
  end

  let(:rails_root) { File.dirname(__FILE__) + '/rails' }

  let(:scout_plugin) do
    MonitorDelayedJobs.new Time.now, nil, 'path_to_app' => rails_root, 'rails_env' => 'test'
  end
  
  before(:each) do
    MonitorDelayedJobs::DelayedJob.delete_all
  end
  
  after(:each) do
    MonitorDelayedJobs::DelayedJob.delete_all
  end
  
  it "should report the total number of jobs" do
    2.times {MonitorDelayedJobs::DelayedJob.create!}
    expect(scout_plugin).to receive(:report).with(hash_including(:total => 2))
    scout_plugin.build_report
  end

  it "should report the total number of jobs of different priorities" do
    2.times {MonitorDelayedJobs::DelayedJob.create! :priority => 10}
    MonitorDelayedJobs::DelayedJob.create! :priority => 5
    expect(scout_plugin).to receive(:report).with(hash_including(:total => 3))
    scout_plugin.build_report
  end

  context 'using a custom loader' do
    let(:rails_root) { File.dirname(__FILE__) + '/rails_custom_loader' }
    let(:scout_plugin) do
      MonitorDelayedJobs.new Time.now, nil,
        'path_to_app' => rails_root, 'rails_env' => 'test', 'custom_loader' => 'lib/custom_loader'
    end

    it "should report the total number of jobs" do
      2.times {MonitorDelayedJobs::DelayedJob.create!}
      expect(scout_plugin).to receive(:report).with(hash_including(:total => 2))
      scout_plugin.build_report
    end
  end
end
