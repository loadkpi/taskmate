require "taskmate/doctor/check"
require "taskmate/doctor/checks/config_reader"

module Taskmate
  module Doctor
    module Checks
      class SecurityConfigCheck < Check
        include ConfigReader

        SAFE_DEFAULTS = {
          "require_consent_for_ai" => true,
          "require_confirm_for_push" => true,
          "secret_detection" => true
        }.freeze

        def initialize(workspace_path:)
          super(name: "security config", description: "Security config has safe defaults")
          @workspace_path = workspace_path
        end

        def run
          config = load_workspace_config(@workspace_path)
          case config
          when :not_found
            return skip!("workspace.yml not found")
          when :invalid_yaml
            return fail!("workspace.yml is not valid YAML — cannot verify security config")
          when :invalid_structure
            return fail!("workspace.yml root is not a mapping — cannot verify security config")
          end

          security = config["security"]
          return fail!("security section missing in workspace.yml") unless security
          return fail!("security section must be a mapping, got #{security.class}") unless security.is_a?(Hash)

          violations = SAFE_DEFAULTS.filter_map do |key, expected|
            "#{key} should be #{expected}" if security[key] != expected
          end

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
