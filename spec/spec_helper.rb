require "simplecov"

SimpleCov.start do
  add_filter "/spec/"
  track_files "lib/**/*.rb"
  minimum_coverage 80
end

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "taskmate"

Dir[File.join(File.dirname(__FILE__), "support", "**", "*.rb")]
  .reject { |f| f.end_with?("_spec.rb") }
  .each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed
end
