require "taskmate/doctor/check"
require "taskmate/workspace/initializer"

module Taskmate
  module Doctor
    module Checks
      class DirectoriesCheck < Check
        def initialize(workspace_path:)
          super(name: "workspace directories", description: "Required workspace directories exist")
          @workspace_path = workspace_path
        end

        def run
          missing = Taskmate::Workspace::DIRECTORIES.reject do |dir|
            Dir.exist?(File.join(@workspace_path, dir))
          end

          if missing.empty?
            ok!("All required directories present")
          else
            fail!("Missing directories: #{missing.join(", ")}. Run `taskmate init`.")
          end
        end
      end
    end
  end
end
