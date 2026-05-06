require "tmpdir"
require "fileutils"
require "yaml"
require "taskmate/workspace/initializer"

module WorkspaceHelpers
  def create_temp_workspace(options = {})
    dir = Dir.mktmpdir("taskmate_spec_")
    @temp_dirs ||= []
    @temp_dirs << dir

    if options[:initialized]
      initializer = Taskmate::Workspace::Initializer.new(
        workspace_path: dir,
        interactive: false,
        prompt: nil
      )
      initializer.call
    end

    File.write(File.join(dir, "workspace.yml"), YAML.dump(options[:workspace_yml])) if options[:workspace_yml]

    dir
  end

  def cleanup_temp_workspaces
    Array(@temp_dirs).each do |dir|
      FileUtils.rm_rf(dir)
    end
    @temp_dirs = []
  end

  def write_file(workspace, relative_path, content)
    full_path = File.join(workspace, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
    full_path
  end
end

RSpec.configure do |config|
  config.include WorkspaceHelpers

  config.after do
    cleanup_temp_workspaces
  end
end
