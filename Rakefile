begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  task(:spec) { abort "RSpec is not available. Run: bundle install" }
end

task default: :spec
