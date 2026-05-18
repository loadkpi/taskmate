require "spec_helper"
require "taskmate/jira/payload_builder"

RSpec.describe Taskmate::Jira::PayloadBuilder do
  let(:push_all) do
    {
      "allow_summary" => true, "allow_description" => true,
      "allow_labels" => true, "allow_components" => true, "allow_priority" => true
    }
  end

  def issue(summary: "My task", issue_type: "Story", body: "Body.",
            labels: [], components: [], priority: "Medium")
    double("issue_file",
           summary: summary, issue_type: issue_type, body: body,
           labels: labels, components: components, priority: priority)
  end

  describe "#build_create" do
    context "with default_project set" do
      subject(:builder) { described_class.new(push_config: push_all, default_project: "PROJ") }

      it "includes project key in fields" do
        payload = builder.build_create(issue)
        expect(payload["fields"]["project"]).to eq({ "key" => "PROJ" })
      end
    end

    context "without default_project" do
      subject(:builder) { described_class.new(push_config: push_all) }

      it "omits project from fields" do
        payload = builder.build_create(issue)
        expect(payload["fields"]).not_to have_key("project")
      end
    end

    context "with empty default_project" do
      subject(:builder) { described_class.new(push_config: push_all, default_project: "") }

      it "omits project from fields" do
        payload = builder.build_create(issue)
        expect(payload["fields"]).not_to have_key("project")
      end
    end

    context "with allowed fields" do
      subject(:builder) { described_class.new(push_config: push_all, default_project: "PROJ") }

      it "includes summary" do
        payload = builder.build_create(issue(summary: "Do something"))
        expect(payload["fields"]["summary"]).to eq("Do something")
      end

      it "includes issuetype" do
        payload = builder.build_create(issue(issue_type: "Bug"))
        expect(payload["fields"]["issuetype"]).to eq({ "name" => "Bug" })
      end

      it "includes labels when present" do
        payload = builder.build_create(issue(labels: ["backend"]))
        expect(payload["fields"]["labels"]).to eq(["backend"])
      end

      it "omits labels when empty" do
        payload = builder.build_create(issue(labels: []))
        expect(payload["fields"]).not_to have_key("labels")
      end

      it "includes priority when present" do
        payload = builder.build_create(issue(priority: "High"))
        expect(payload["fields"]["priority"]).to eq({ "name" => "High" })
      end
    end

    context "with no allowed fields" do
      subject(:builder) do
        described_class.new(
          push_config: {
            "allow_summary" => false, "allow_description" => false,
            "allow_labels" => false, "allow_components" => false, "allow_priority" => false
          },
          default_project: "PROJ"
        )
      end

      it "still includes project and issuetype" do
        payload = builder.build_create(issue)
        expect(payload["fields"]).to have_key("project")
        expect(payload["fields"]).to have_key("issuetype")
        expect(payload["fields"]).not_to have_key("summary")
      end
    end
  end

  describe "#build_update" do
    subject(:builder) { described_class.new(push_config: push_all, default_project: "PROJ") }

    it "never includes project in update payload" do
      iss = issue(summary: "Changed")
      payload = builder.build_update(iss, jira_fields: { "summary" => "Old" })
      expect(payload["fields"]).not_to have_key("project")
    end

    it "includes changed summary" do
      iss = issue(summary: "New title")
      payload = builder.build_update(iss, jira_fields: { "summary" => "Old title" })
      expect(payload["fields"]["summary"]).to eq("New title")
    end

    it "omits unchanged summary" do
      iss = issue(summary: "Same")
      payload = builder.build_update(iss, jira_fields: { "summary" => "Same" })
      expect(payload["fields"]).not_to have_key("summary")
    end

    it "includes changed labels" do
      iss = issue(labels: ["new"])
      payload = builder.build_update(iss, jira_fields: { "labels" => ["old"] })
      expect(payload["fields"]["labels"]).to eq(["new"])
    end

    it "includes changed priority" do
      iss = issue(priority: "High")
      payload = builder.build_update(iss, jira_fields: { "priority" => { "name" => "Low" } })
      expect(payload["fields"]["priority"]).to eq({ "name" => "High" })
    end
  end
end
