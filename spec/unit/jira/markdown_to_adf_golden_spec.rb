require "spec_helper"
require "json"
require "taskmate/jira/markdown_to_adf"

RSpec.describe "Markdown → ADF golden file tests" do
  FIXTURES_DIR = File.expand_path("../../fixtures/md_to_adf", __dir__)

  subject(:converter) { Taskmate::Jira::MarkdownToAdf.new }

  # Discover all .md files in the fixtures directory
  md_files = Dir[File.join(FIXTURES_DIR, "*.md")].sort

  md_files.each do |md_path|
    name     = File.basename(md_path, ".md")
    adf_path = File.join(FIXTURES_DIR, "#{name}.adf.json")

    it "converts #{name}.md to expected ADF" do
      skip "No golden .adf.json for #{name}" unless File.exist?(adf_path)

      markdown = File.read(md_path, encoding: "utf-8")
      expected = JSON.parse(File.read(adf_path, encoding: "utf-8"))
      actual   = converter.convert(markdown)

      expect(actual).to eq(expected)
    end
  end
end
