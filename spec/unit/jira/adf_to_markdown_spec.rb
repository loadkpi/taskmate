require "spec_helper"
require "taskmate/jira/adf_to_markdown"
require "json"

RSpec.describe Taskmate::Jira::AdfToMarkdown do
  subject(:converter) { described_class.new }

  FIXTURES_DIR = File.expand_path("../../fixtures/adf", __dir__)

  def adf(name)
    JSON.parse(File.read(File.join(FIXTURES_DIR, "#{name}.json")))
  end

  def golden(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.md"))
  end

  describe "golden file tests" do
    %w[headings paragraph lists marks code_block unsupported].each do |fixture|
      it "converts #{fixture} correctly" do
        result = converter.convert(adf(fixture))
        expect(result.markdown).to eq(golden(fixture))
      end
    end

    it "headings fixture has no unsupported nodes" do
      result = converter.convert(adf("headings"))
      expect(result.unsupported_nodes).to be_empty
    end

    it "unsupported fixture reports 'table' as unsupported" do
      result = converter.convert(adf("unsupported"))
      expect(result.unsupported_nodes).to include("table")
    end
  end

  describe "#convert" do
    context "headings" do
      it "converts level 1 heading" do
        node = { "type" => "doc", "content" => [
          { "type" => "heading", "attrs" => { "level" => 1 },
            "content" => [{ "type" => "text", "text" => "Title" }] }
        ] }
        expect(converter.convert(node).markdown).to include("# Title")
      end

      it "converts level 3 heading" do
        node = { "type" => "doc", "content" => [
          { "type" => "heading", "attrs" => { "level" => 3 },
            "content" => [{ "type" => "text", "text" => "Sub" }] }
        ] }
        expect(converter.convert(node).markdown).to include("### Sub")
      end
    end

    context "text marks" do
      def text_node(text, *mark_types)
        marks = mark_types.map { |t| { "type" => t } }
        { "type" => "doc", "content" => [
          { "type" => "paragraph", "content" => [
            { "type" => "text", "text" => text, "marks" => marks }
          ] }
        ] }
      end

      it "renders bold with **" do
        expect(converter.convert(text_node("hi", "strong")).markdown).to include("**hi**")
      end

      it "renders italic with *" do
        expect(converter.convert(text_node("hi", "em")).markdown).to include("*hi*")
      end

      it "renders inline code with backtick" do
        expect(converter.convert(text_node("x", "code")).markdown).to include("`x`")
      end

      it "renders links with [text](url)" do
        node = { "type" => "doc", "content" => [
          { "type" => "paragraph", "content" => [
            { "type" => "text", "text" => "click",
              "marks" => [{ "type" => "link", "attrs" => { "href" => "https://example.com" } }] }
          ] }
        ] }
        expect(converter.convert(node).markdown).to include("[click](https://example.com)")
      end
    end

    context "code block" do
      it "wraps content in fenced code block" do
        node = { "type" => "doc", "content" => [
          { "type" => "codeBlock", "attrs" => { "language" => "python" },
            "content" => [{ "type" => "text", "text" => "print(1)" }] }
        ] }
        md = converter.convert(node).markdown
        expect(md).to include("```python")
        expect(md).to include("print(1)")
      end
    end

    context "bullet list" do
      it "uses - prefix for bullet items" do
        node = { "type" => "doc", "content" => [
          { "type" => "bulletList", "content" => [
            { "type" => "listItem", "content" => [
              { "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Item" }] }
            ] }
          ] }
        ] }
        expect(converter.convert(node).markdown).to include("- Item")
      end
    end

    context "ordered list" do
      it "uses 1. prefix for first ordered item" do
        node = { "type" => "doc", "content" => [
          { "type" => "orderedList", "content" => [
            { "type" => "listItem", "content" => [
              { "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Step" }] }
            ] }
          ] }
        ] }
        expect(converter.convert(node).markdown).to include("1. Step")
      end
    end

    context "hard break" do
      it "converts hardBreak to newline" do
        node = { "type" => "doc", "content" => [
          { "type" => "paragraph", "content" => [
            { "type" => "text", "text" => "line1" },
            { "type" => "hardBreak" },
            { "type" => "text", "text" => "line2" }
          ] }
        ] }
        md = converter.convert(node).markdown
        expect(md).to include("line1\nline2")
      end
    end

    context "unsupported nodes" do
      it "emits comment placeholder for unknown node types" do
        node = { "type" => "doc", "content" => [
          { "type" => "mediaSingle", "content" => [] }
        ] }
        md = converter.convert(node).markdown
        expect(md).to include('<!-- taskmate: unsupported_adf_node type="mediaSingle" -->')
      end

      it "reports unsupported node type in result" do
        node = { "type" => "doc", "content" => [
          { "type" => "expand", "content" => [] }
        ] }
        result = converter.convert(node)
        expect(result.unsupported_nodes).to include("expand")
      end

      it "dedups multiple occurrences of the same unsupported node" do
        node = { "type" => "doc", "content" => [
          { "type" => "table", "content" => [] },
          { "type" => "table", "content" => [] }
        ] }
        result = converter.convert(node)
        expect(result.unsupported_nodes.count { |n| n == "table" }).to eq(1)
      end
    end

    context "nil / empty input" do
      it "returns empty markdown for nil" do
        expect(converter.convert(nil).markdown).to eq("")
      end

      it "returns empty markdown for empty hash" do
        expect(converter.convert({}).markdown).to eq("")
      end
    end
  end
end
