require "taskmate/doctor/check"

module Taskmate
  module Doctor
    module Checks
      class NoSecretsCheck < Check
        # Simple heuristic patterns — full SecretRedactor is in M3-T1
        SECRET_PATTERNS = [
          /AKIA[0-9A-Z]{16}/,             # AWS access key
          /ghp_[0-9A-Za-z]{36}/,          # GitHub personal token
          /glpat-[0-9A-Za-z-]{20}/, # GitLab token
          /-----BEGIN [A-Z ]*PRIVATE KEY/, # Private key block
          /Bearer\s+ey[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+/ # JWT
        ].freeze

        def initialize(workspace_path:)
          super(name: "no secrets in workspace root", description: "No secret-like content in root files")
          @workspace_path = workspace_path
        end

        def run
          suspicious = []

          # Include dotfiles (e.g. .env, .netrc) via FNM_DOTMATCH
          all_root_files = Dir.glob(File.join(@workspace_path, "*"), File::FNM_DOTMATCH)
                              .select { |f| File.file?(f) }

          all_root_files.each do |file|
            content = File.read(file, encoding: "utf-8")
            SECRET_PATTERNS.each do |pattern|
              if content.match?(pattern)
                suspicious << File.basename(file)
                break
              end
            end
          rescue StandardError
            # unreadable / binary file — skip
          end

          if suspicious.empty?
            ok!("No secrets detected in workspace root files")
          else
            fail!("Possible secrets detected in: #{suspicious.join(', ')}. " \
                  "Add these files to .taskmateignore and rotate any exposed credentials.")
          end
        end
      end
    end
  end
end
