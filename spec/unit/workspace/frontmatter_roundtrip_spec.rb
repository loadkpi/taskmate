require "spec_helper"
require "taskmate/workspace/frontmatter_file"

GOLDEN_FIXTURE = <<~MD.freeze
  ---
  key: SAR-1
  summary: Fix the login bug
  status: In Progress
  priority: High
  issue_type: Bug
  labels:
  - backend
  - auth
  assignee:
    account_id: abc123
    display_name: Alice
    email: alice@example.com
  jira_source_hash: sha256:aabbcc
  last_synced_local_hash: sha256:ddeeff
  ---
  ## Description

  The login button stops working after session timeout.

  ## Steps to reproduce

  1. Log in
  2. Wait 30 minutes
  3. Click login again
MD

RSpec.describe "Frontmatter round-trip" do
  it "parses scalar fields from the golden fixture" do
    ff = Taskmate::Workspace::FrontmatterFile.parse(GOLDEN_FIXTURE)
    expect(ff.frontmatter["key"]).to eq("SAR-1")
    expect(ff.frontmatter["summary"]).to eq("Fix the login bug")
    expect(ff.frontmatter["status"]).to eq("In Progress")
    expect(ff.frontmatter["priority"]).to eq("High")
    expect(ff.frontmatter["issue_type"]).to eq("Bug")
  end

  it "parses collection fields and body from the golden fixture" do
    ff = Taskmate::Workspace::FrontmatterFile.parse(GOLDEN_FIXTURE)
    expect(ff.frontmatter["labels"]).to eq(%w[backend auth])
    expect(ff.frontmatter["jira_source_hash"]).to eq("sha256:aabbcc")
    expect(ff.frontmatter["last_synced_local_hash"]).to eq("sha256:ddeeff")
    expect(ff.body).to include("The login button stops working")
  end

  it "serializes back to a string that re-parses identically" do
    ff1 = Taskmate::Workspace::FrontmatterFile.parse(GOLDEN_FIXTURE)
    serialized = ff1.serialize
    ff2 = Taskmate::Workspace::FrontmatterFile.parse(serialized)
    expect(ff2.frontmatter).to eq(ff1.frontmatter)
    expect(ff2.body.strip).to eq(ff1.body.strip)
  end

  it "serialized output contains expected YAML key-value fragments" do
    ff = Taskmate::Workspace::FrontmatterFile.parse(GOLDEN_FIXTURE)
    out = ff.serialize
    expect(out).to start_with("---\n")
    expect(out).to include("key: SAR-1")
    expect(out).to include("summary: Fix the login bug")
    expect(out).to include("issue_type: Bug")
  end

  it "serialized output has correct structure and body" do
    ff = Taskmate::Workspace::FrontmatterFile.parse(GOLDEN_FIXTURE)
    out = ff.serialize
    # Labels must serialize as a sequence, not inline
    expect(out).to match(/labels:\n- backend\n- auth/)
    # Exactly two --- delimiters: one opening, one closing the frontmatter block
    expect(out.scan(/^---$/).size).to eq(2)
    expect(out).to include("The login button stops working")
  end

  it "round-trips through a temp file" do
    dir = Dir.mktmpdir
    begin
      path = File.join(dir, "SAR-1.md")
      ff1 = Taskmate::Workspace::FrontmatterFile.parse(GOLDEN_FIXTURE)
      File.write(path, ff1.serialize)
      ff2 = Taskmate::Workspace::FrontmatterFile.parse(File.read(path))
      expect(ff2.frontmatter).to eq(ff1.frontmatter)
      expect(ff2.body.strip).to eq(ff1.body.strip)
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  it "handles CRLF line endings transparently" do
    crlf_content = GOLDEN_FIXTURE.gsub("\n", "\r\n")
    ff = Taskmate::Workspace::FrontmatterFile.parse(crlf_content)
    expect(ff.frontmatter["key"]).to eq("SAR-1")
    expect(ff.frontmatter["labels"]).to eq(%w[backend auth])
  end
end
