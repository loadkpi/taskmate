require "spec_helper"

RSpec.describe "WorkspaceHelpers#cleanup_temp_workspaces" do
  it "removes directories created by create_temp_workspace" do
    dir = create_temp_workspace
    expect(Dir.exist?(dir)).to be(true)

    cleanup_temp_workspaces

    expect(Dir.exist?(dir)).to be(false)
  end

  it "removes multiple temp directories in one call" do
    dirs = Array.new(3) { create_temp_workspace }
    dirs.each { |d| expect(Dir.exist?(d)).to be(true) }

    cleanup_temp_workspaces

    dirs.each { |d| expect(Dir.exist?(d)).to be(false) }
  end

  it "does not raise when called with no previously created dirs" do
    cleanup_temp_workspaces # reset @temp_dirs to []
    expect { cleanup_temp_workspaces }.not_to raise_error
  end
end
