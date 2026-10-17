# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "flipper rake tasks" do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("flipper:enable") }

  def run_task(name, feature)
    task = Rake::Task[name]
    task.reenable
    expect { task.invoke(feature) }.to output(/#{feature} is (on|off)/).to_stdout
  end

  it "turns a feature on and off" do
    Flipper.disable(:chat)

    run_task("flipper:enable", "chat")
    expect(Flipper.enabled?(:chat)).to be(true)

    run_task("flipper:disable", "chat")
    expect(Flipper.enabled?(:chat)).to be(false)
  end
end
