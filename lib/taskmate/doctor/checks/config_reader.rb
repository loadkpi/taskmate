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
      end
    end
  end
end
