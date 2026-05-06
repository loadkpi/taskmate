require "spec_helper"

RSpec.describe Taskmate do
  describe "VERSION" do
    it "is a semantic version string" do
      expect(Taskmate::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end

    it "is not nil" do
      expect(Taskmate::VERSION).not_to be_nil
    end
  end

  describe "error hierarchy" do
    it "defines base Error inheriting from StandardError" do
      expect(Taskmate::Error.ancestors).to include(StandardError)
    end

    it "defines JiraAuthError as a subclass of JiraError" do
      expect(Taskmate::JiraAuthError.ancestors).to include(Taskmate::JiraError)
    end

    it "defines AiAuthError as a subclass of AiError" do
      expect(Taskmate::AiAuthError.ancestors).to include(Taskmate::AiError)
    end

    it "defines ConsentDeniedError as a subclass of Error" do
      expect(Taskmate::ConsentDeniedError.ancestors).to include(Taskmate::Error)
    end
  end
end
