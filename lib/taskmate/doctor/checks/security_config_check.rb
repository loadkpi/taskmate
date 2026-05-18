require "taskmate/doctor/check"
require "taskmate/config"

module Taskmate
  module Doctor
    module Checks
      class SecurityConfigCheck < Check
        def initialize(workspace_path:)
          super(name: "security config", description: "Security config has safe defaults")
          @workspace_path = workspace_path
        end

        def run
          raw = Config::Loader.load_raw(@workspace_path)
          case raw
          when :not_found
            return skip!("workspace.yml not found")
          when :invalid_yaml
            return fail!("workspace.yml is not valid YAML — cannot verify security config")
          when :invalid_structure
            return fail!("workspace.yml root is not a mapping — cannot verify security config")
          end

          security = raw["security"]
          return fail!("security section missing in workspace.yml") unless security
          return fail!("security section must be a mapping, got #{security.class}") unless security.is_a?(Hash)

          begin
            cfg = Config::Loader.load(@workspace_path)
          rescue Taskmate::ConfigError => e
            return fail!("Config invalid: #{e.message}")
          end
          sec        = cfg.security
          violations = []
          violations << "require_consent_for_ai should be true"   unless sec.require_consent_for_ai
          violations << "require_confirm_for_push should be true" unless sec.require_confirm_for_push
          violations << "secret_detection should be true"         unless sec.secret_detection

          if violations.empty?
            ok!("Security config has safe defaults")
          else
            fail!("Unsafe security config: #{violations.join('; ')}")
          end
        end
      end
    end
  end
end
