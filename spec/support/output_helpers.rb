require "stringio"

module OutputHelpers
  def capture_stdout
    original_stdout = $stdout
    fake_stdout = StringIO.new
    $stdout = fake_stdout
    yield
    fake_stdout.string
  ensure
    $stdout = original_stdout
  end

  def capture_stdout_and_system_exit
    original_stdout = $stdout
    fake_stdout = StringIO.new
    $stdout = fake_stdout

    begin
      yield
      [fake_stdout.string, nil]
    rescue SystemExit => e
      [fake_stdout.string, e]
    ensure
      $stdout = original_stdout
    end
  end
end

RSpec.configure do |config|
  config.include OutputHelpers
end
