require "spec_helper"
require "taskmate/jira/adf_to_markdown"
require "json"

RSpec.describe Taskmate::Jira::AdfToMarkdown do
  subject(:converter) { described_class.new }

  def fixtures_dir
    File.expand_path("../../fixtures/adf", __dir__)
  end

  def adf(name)
    JSON.parse(File.read(File.join(fixtures_dir, "#{name}.json")))
  end

  def golden(name)
    File.read(File.join(fixtures_dir, "#{name}.md"))
  end

  describe "golden file tests" do
    %w[headings paragraph lists nested_lists marks code_block unsupported].each do |fixture|
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

    context "nested bullet list" do
      def nested_bullet_doc(parent_text, *child_texts)
        children = child_texts.map do |t|
          { "type" => "listItem", "content" => [
            { "type" => "paragraph", "content" => [{ "type" => "text", "text" => t }] }
          ] }
        end
        { "type" => "doc", "content" => [
          { "type" => "bulletList", "content" => [
            { "type" => "listItem", "content" => [
              { "type" => "paragraph", "content" => [{ "type" => "text", "text" => parent_text }] },
              { "type" => "bulletList", "content" => children }
            ] }
          ] }
        ] }
      end

      it "indents nested bullet items by two spaces" do
        md = converter.convert(nested_bullet_doc("Parent", "Child")).markdown
        expect(md).to include("- Parent\n  - Child")
      end

      it "indents multiple nested bullet items" do
        md = converter.convert(nested_bullet_doc("Parent", "A", "B")).markdown
        expect(md).to include("  - A\n  - B")
      end
    end

    context "nested ordered list" do
      def nested_ordered_doc(parent_text, *child_texts)
        children = child_texts.map do |t|
          { "type" => "listItem", "content" => [
            { "type" => "paragraph", "content" => [{ "type" => "text", "text" => t }] }
          ] }
        end
        { "type" => "doc", "content" => [
          { "type" => "orderedList", "content" => [
            { "type" => "listItem", "content" => [
              { "type" => "paragraph", "content" => [{ "type" => "text", "text" => parent_text }] },
              { "type" => "orderedList", "content" => children }
            ] }
          ] }
        ] }
      end

      it "indents nested ordered items by three spaces" do
        md = converter.convert(nested_ordered_doc("Step", "Sub")).markdown
        expect(md).to include("1. Step\n   1. Sub")
      end
    end

    context "mixed nested list" do
      it "indents ordered items nested under a bullet item using the bullet continuation indent" do
        node = { "type" => "doc", "content" => [
          { "type" => "bulletList", "content" => [
            { "type" => "listItem", "content" => [
              { "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Tasks" }] },
              { "type" => "orderedList", "content" => [
                { "type" => "listItem", "content" => [
                  { "type" => "paragraph", "content" => [{ "type" => "text", "text" => "First" }] }
                ] }
              ] }
            ] }
          ] }
        ] }
        md = converter.convert(node).markdown
        expect(md).to include("- Tasks\n  1. First")
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
