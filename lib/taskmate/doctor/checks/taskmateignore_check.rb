require "taskmate/doctor/check"

module Taskmate
  module Doctor
    module Checks
      class TaskmateignoreCheck < Check
        def initialize(workspace_path:)
          super(name: ".taskmateignore", description: ".taskmateignore file exists")
          @workspace_path = workspace_path
        end

        def run
          path = File.join(@workspace_path, ".taskmateignore")
          if File.exist?(path)
            ok!(".taskmateignore present")
          else
            fail!(".taskmateignore not found. Run `taskmate init` to create it.")
          end
        end
      end
    end
  end
end
