require "yaml"

module Taskmate
  module Doctor
    module Checks
      module ConfigReader
        # Returns one of:
        #   :not_found       — workspace.yml doesn't exist
        #   :invalid_yaml    — file exists but is not valid YAML
        #   :invalid_structure — valid YAML but root is not a Hash
        #   Hash             — parsed config
        def load_workspace_config(workspace_path)
          path = File.join(workspace_path, "workspace.yml")
          return :not_found unless File.exist?(path)

          parsed = YAML.safe_load_file(path)
          return :invalid_structure unless parsed.is_a?(Hash)

          parsed
        rescue Psych::Exception
          :invalid_yaml
        end

        def safe_dig(hash, *keys)
          hash.dig(*keys).to_s
        rescue TypeError, NoMethodError
          ""
        end

        # Returns ENV override, then tracker.base_url, then legacy jira.base_url, then "".
        # Dual-key fallback is kept for backward compatibility with pre-init workspace.yml files.
        def jira_base_url(config)
          ENV.fetch("TASKMATE_JIRA_URL",
                    if config.is_a?(Hash)
                      safe_dig(config, "tracker", "base_url").then do |v|
                        v.empty? ? safe_dig(config, "jira", "base_url") : v
                      end
                    else
                      ""
                    end)
        end

        # Returns tracker.story_points_field, falling back to legacy jira.story_points_field.
        def story_points_field(config)
          return nil unless config.is_a?(Hash)

          config.dig("tracker", "story_points_field") || config.dig("jira", "story_points_field")
        end
      end
    end
  end
end
