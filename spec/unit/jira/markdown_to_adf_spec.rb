require "spec_helper"
require "taskmate/jira/markdown_to_adf"
require "taskmate/jira/adf_to_markdown"

RSpec.describe Taskmate::Jira::MarkdownToAdf do
  subject(:converter) { described_class.new }

  let(:back_converter) { Taskmate::Jira::AdfToMarkdown.new }

  describe "#convert" do
    context "headings" do
      it "converts H1 to heading node" do
        adf = converter.convert("# Title\n")
        heading = adf.dig("content", 0)
        expect(heading["type"]).to eq("heading")
        expect(heading.dig("attrs", "level")).to eq(1)
        expect(heading.dig("content", 0, "text")).to eq("Title")
      end

      it "converts H3 to heading level 3" do
        adf = converter.convert("### Sub\n")
        expect(adf.dig("content", 0, "attrs", "level")).to eq(3)
      end
    end

    context "paragraphs" do
      it "converts plain text to paragraph node" do
        adf = converter.convert("Hello world.\n")
        para = adf.dig("content", 0)
        expect(para["type"]).to eq("paragraph")
        expect(para.dig("content", 0, "text")).to eq("Hello world.")
      end
    end

    context "bullet list" do
      it "converts - items to bulletList" do
        adf = converter.convert("- Apple\n- Banana\n")
        list = adf.dig("content", 0)
        expect(list["type"]).to eq("bulletList")
        expect(list["content"].size).to eq(2)
        expect(list.dig("content", 0, "type")).to eq("listItem")
      end
    end

    context "ordered list" do
      it "converts 1. items to orderedList" do
        adf = converter.convert("1. First\n2. Second\n")
        list = adf.dig("content", 0)
        expect(list["type"]).to eq("orderedList")
        expect(list["content"].size).to eq(2)
      end
    end

    context "code block" do
      it "converts fenced code block" do
        adf = converter.convert("```ruby\nputs 1\n```\n")
        block = adf.dig("content", 0)
        expect(block["type"]).to eq("codeBlock")
        expect(block.dig("attrs", "language")).to eq("ruby")
        expect(block.dig("content", 0, "text")).to eq("puts 1")
      end
    end

    context "inline marks" do
      it "converts **bold** to strong mark" do
        adf = converter.convert("Hello **world**.\n")
        para = adf.dig("content", 0)
        bold_node = para["content"].find { |n| n["text"] == "world" }
        expect(bold_node["marks"].map { |m| m["type"] }).to include("strong")
      end

      it "converts *italic* to em mark" do
        adf = converter.convert("Hello *world*.\n")
        para = adf.dig("content", 0)
        italic_node = para["content"].find { |n| n["text"] == "world" }
        expect(italic_node["marks"].map { |m| m["type"] }).to include("em")
      end

      it "converts `code` to code mark" do
        adf = converter.convert("Run `cmd` now.\n")
        para      = adf.dig("content", 0)
        code_node = para["content"].find { |n| n["text"] == "cmd" }
        expect(code_node["marks"].map { |m| m["type"] }).to include("code")
      end

      it "converts [text](url) to link mark" do
        adf = converter.convert("[click here](https://example.com)\n")
        para = adf.dig("content", 0)
        node = para["content"].find { |n| n["text"] == "click here" }
        link_mark = node["marks"].find { |m| m["type"] == "link" }
        expect(link_mark.dig("attrs", "href")).to eq("https://example.com")
      end
    end

    context "empty input" do
      it "returns doc with empty content for nil" do
        adf = converter.convert(nil)
        expect(adf["type"]).to eq("doc")
        expect(adf["content"]).to be_empty
      end
    end
  end

  describe "round-trip stability" do
    def round_trip(markdown)
      adf = converter.convert(markdown)
      back_converter.convert(adf).markdown
    end

    it "round-trips headings" do
      md = "# Title\n\n## Section\n"
      expect(round_trip(md)).to include("# Title")
      expect(round_trip(md)).to include("## Section")
    end

    it "round-trips bullet list" do
      md = "- Apple\n- Banana\n"
      result = round_trip(md)
      expect(result).to include("- Apple")
      expect(result).to include("- Banana")
    end

    it "round-trips ordered list" do
      md = "1. First\n2. Second\n"
      result = round_trip(md)
      expect(result).to include("1. First")
      expect(result).to include("2. Second")
    end

    it "round-trips code block" do
      md = "```ruby\nputs 1\n```\n"
      result = round_trip(md)
      expect(result).to include("```ruby")
      expect(result).to include("puts 1")
    end

    it "round-trips bold text" do
      md = "Hello **world**.\n"
      result = round_trip(md)
      expect(result).to include("**world**")
    end

    it "round-trips italic text" do
      md = "Hello *world*.\n"
      result = round_trip(md)
      expect(result).to include("*world*")
    end

    it "round-trips links" do
      md = "[click](https://example.com)\n"
      result = round_trip(md)
      expect(result).to include("[click](https://example.com)")
    end
  end
end
