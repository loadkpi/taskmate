require "taskmate/doctor/check"
require "taskmate/doctor/checks/config_reader"

module Taskmate
  module Doctor
    module Checks
      class WorkspaceYmlCheck < Check
        include ConfigReader

        def initialize(workspace_path:)
          super(name: "workspace.yml", description: "workspace.yml exists and parses correctly")
          @workspace_path = workspace_path
        end

        def run
          case load_workspace_config(@workspace_path)
          when :not_found
            fail!("workspace.yml not found. Run `taskmate init` to create it.")
          when :invalid_yaml
            fail!("workspace.yml is not valid YAML")
          when :invalid_structure
            fail!("workspace.yml must be a YAML mapping (key: value), got a different type")
          else
            ok!("workspace.yml is valid YAML")
          end
        end
      end
    end
  end
end
