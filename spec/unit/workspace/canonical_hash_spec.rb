require "spec_helper"
require "taskmate/workspace/canonical_hash"

RSpec.describe Taskmate::Workspace::CanonicalHash do
  let(:base_fm) do
    {
      "key" => "SAR-1",
      "summary" => "Fix bug",
      "issue_type" => "Bug",
      "priority" => "High",
      "labels" => %w[backend auth],
      "components" => ["API"],
      "story_points" => 3,
      "due_date" => "2025-06-01",
      "status" => "Open",
      "last_pulled_at" => "2025-01-01",
      "sync_state" => "clean"
    }
  end
  let(:base_body) { "Some description\n" }

  describe ".compute" do
    it "returns a sha256: prefixed string" do
      h = described_class.compute(frontmatter: base_fm, body: base_body)
      expect(h).to match(/\Asha256:[0-9a-f]{64}\z/)
    end

    it "same content produces same hash" do
      h1 = described_class.compute(frontmatter: base_fm, body: base_body)
      h2 = described_class.compute(frontmatter: base_fm.dup, body: base_body.dup)
      expect(h1).to eq(h2)
    end

    it "changing summary produces different hash" do
      h1 = described_class.compute(frontmatter: base_fm, body: base_body)
      h2 = described_class.compute(frontmatter: base_fm.merge("summary" => "Different"), body: base_body)
      expect(h1).not_to eq(h2)
    end

    it "changing body produces different hash" do
      h1 = described_class.compute(frontmatter: base_fm, body: base_body)
      h2 = described_class.compute(frontmatter: base_fm, body: "Different body\n")
      expect(h1).not_to eq(h2)
    end

    it "changing last_pulled_at does NOT change hash (excluded field)" do
      h1 = described_class.compute(frontmatter: base_fm, body: base_body)
      h2 = described_class.compute(frontmatter: base_fm.merge("last_pulled_at" => "2099-01-01"), body: base_body)
      expect(h1).to eq(h2)
    end

    it "changing status does NOT change hash (excluded field)" do
      h1 = described_class.compute(frontmatter: base_fm, body: base_body)
      h2 = described_class.compute(frontmatter: base_fm.merge("status" => "In Progress"), body: base_body)
      expect(h1).to eq(h2)
    end

    it "does not crash when a field contains an array of hashes" do
      fm = base_fm.merge("labels" => [{ "id" => "b1" }, { "id" => "b2" }])
      expect { described_class.compute(frontmatter: fm, body: base_body) }.not_to raise_error
    end

    it "label order does not affect hash (sorted)" do
      fm1 = base_fm.merge("labels" => %w[auth backend])
      fm2 = base_fm.merge("labels" => %w[backend auth])
      h1 = described_class.compute(frontmatter: fm1, body: base_body)
      h2 = described_class.compute(frontmatter: fm2, body: base_body)
      expect(h1).to eq(h2)
    end
  end
end
