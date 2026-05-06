require "spec_helper"
require "taskmate/workspace/frontmatter_file"

RSpec.describe Taskmate::Workspace::FrontmatterFile do
  let(:valid_content) do
    <<~MD
      ---
      key: SAR-123
      summary: Fix login bug
      priority: High
      labels:
        - backend
        - auth
      ---
      ## Description

      Users cannot log in after password reset.
    MD
  end

  describe ".parse" do
    it "parses frontmatter into a Hash" do
      ff = described_class.parse(valid_content)
      expect(ff.frontmatter).to be_a(Hash)
      expect(ff.frontmatter["key"]).to eq("SAR-123")
      expect(ff.frontmatter["summary"]).to eq("Fix login bug")
    end

    it "parses body correctly" do
      ff = described_class.parse(valid_content)
      expect(ff.body).to include("Users cannot log in")
    end

    it "handles multiline YAML values" do
      content = <<~MD
        ---
        key: SAR-1
        summary: |
          A long
          multiline summary
        ---
        Body here
      MD
      ff = described_class.parse(content)
      expect(ff.frontmatter["summary"]).to include("A long")
    end

    it "handles empty body" do
      content = "---\nkey: SAR-1\n---\n"
      ff = described_class.parse(content)
      expect(ff.body).to eq("")
    end

    it "parses labels as array" do
      ff = described_class.parse(valid_content)
      expect(ff.frontmatter["labels"]).to eq(%w[backend auth])
    end

    it "raises InvalidFrontmatterError when no frontmatter delimiter" do
      expect do
        described_class.parse("Just plain markdown\nNo frontmatter here")
      end.to raise_error(Taskmate::InvalidFrontmatterError, /no frontmatter delimiter/i)
    end

    it "raises InvalidFrontmatterError on missing closing ---" do
      expect do
        described_class.parse("---\nkey: val\nno closing delimiter")
      end.to raise_error(Taskmate::InvalidFrontmatterError, /closing ---/i)
    end

    it "raises InvalidFrontmatterError on invalid YAML" do
      expect do
        described_class.parse("---\nkey: [unclosed\n---\nbody")
      end.to raise_error(Taskmate::InvalidFrontmatterError, /invalid yaml/i)
    end

    it "parses CRLF line endings correctly" do
      content = "---\r\nkey: SAR-1\r\nsummary: Test\r\n---\r\nBody here"
      ff = described_class.parse(content)
      expect(ff.frontmatter["key"]).to eq("SAR-1")
      expect(ff.body).to include("Body here")
    end

    it "handles Date values in frontmatter" do
      content = "---\ndue_date: 2025-06-01\n---\nbody"
      expect { described_class.parse(content) }.not_to raise_error
    end

    it "raises InvalidFrontmatterError when frontmatter is not a mapping" do
      expect do
        described_class.parse("---\n- item1\n- item2\n---\nbody")
      end.to raise_error(Taskmate::InvalidFrontmatterError, /mapping/i)
    end
  end

  describe ".serialize" do
    it "produces valid frontmatter + body" do
      result = described_class.serialize({ "key" => "SAR-1", "summary" => "Test" }, "Body text")
      expect(result).to start_with("---\n")
      expect(result).to include("key: SAR-1")
      expect(result).to include("---\nBody text")
    end
  end

  describe "round-trip" do
    it "parse(serialize(fm, body)) == (fm, body)" do
      fm   = { "key" => "SAR-123", "labels" => %w[a b] }
      body = "Some body text\n"

      serialized = described_class.serialize(fm, body)
      parsed     = described_class.parse(serialized)

      expect(parsed.frontmatter).to eq(fm)
      expect(parsed.body).to eq(body)
    end
  end

  describe "#serialize" do
    it "produces the same as class method" do
      ff     = described_class.parse(valid_content)
      result = ff.serialize
      expect(described_class.parse(result).frontmatter).to eq(ff.frontmatter)
    end
  end
end
