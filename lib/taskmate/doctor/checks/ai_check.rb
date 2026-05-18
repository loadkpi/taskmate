require "taskmate/doctor/check"
require "taskmate/config"

module Taskmate
  module Doctor
    module Checks
      # Full online AI provider check is added in M6.
      # Here we only report skip/configured status based on workspace.yml.
      class AiCheck < Check
        def initialize(workspace_path:)
          super(name: "AI provider", description: "AI provider is available")
          @workspace_path = workspace_path
        end

        def run
          raw = Config::Loader.load_raw(@workspace_path)
          case raw
          when :not_found
            return skip!("workspace.yml not found")
          when :invalid_yaml, :invalid_structure
            return skip!("workspace.yml is malformed — skipping AI check")
          end

          begin
            cfg = Config::Loader.load(@workspace_path)
          rescue Taskmate::ConfigError => e
            return fail!("Config invalid: #{e.message}")
          end
          provider = cfg.ai.provider.to_s
          if provider.empty? || provider == "disabled"
            skip!("AI provider disabled in workspace.yml (online check added in M6)")
          else
            skip!("AI provider #{provider} configured — online check added in M6")
          end
        end
      end
    end
  end
end
