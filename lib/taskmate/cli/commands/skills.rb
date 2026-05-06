require "taskmate/skills/registry"
require "taskmate/skills/loader"
require "taskmate/skills/differ"

module Taskmate
  module CLI
    module Commands
      class Skills
        VALID_FORMATS = %w[text json].freeze

        def initialize(options = {})
          @options = options
        end

        def list(workspace_path = Dir.pwd)
          validate_format!
          registry = ::Taskmate::Skills::Registry.new(workspace_path: workspace_path)
          skills   = registry.all

          if fmt == "json"
            require "json"
            puts JSON.pretty_generate(skills.map { |s| skill_summary(s) })
          else
            if skills.empty?
              puts "No skills found in #{workspace_path}/skills/"
            else
              skills.each do |s|
                puts "  %-30s  v%-6s  %s" % [s.id, s.version.to_s, s.kind.to_s]
              end
            end
          end
        end

        def show(skill_id, workspace_path = Dir.pwd)
          validate_format!
          registry = ::Taskmate::Skills::Registry.new(workspace_path: workspace_path)
          skill    = registry.find(skill_id)

          if fmt == "json"
            require "json"
            puts JSON.pretty_generate(skill_detail(skill))
          else
            puts "id:          #{skill.id}"
            puts "version:     #{skill.version}"
            puts "kind:        #{skill.kind}"
            puts "description: #{skill.description}"
            puts "requires_ai: #{skill.requires_ai}"
            puts "\nInputs:"
            skill.inputs.each { |i| puts "  - #{i["name"]} (#{i["type"]})" }
            puts "\nOutputs:"
            skill.outputs.each { |o| puts "  - #{o["name"]} (#{o["type"]})" }
          end
        end

        def validate(workspace_path = Dir.pwd)
          registry = ::Taskmate::Skills::Registry.new(workspace_path: workspace_path)
          results  = registry.validate_all
          all_valid = results.all? { |r| r[:result].valid? }

          if fmt == "json"
            require "json"
            puts JSON.pretty_generate(results.map { |r|
              { "id" => r[:skill].id, "valid" => r[:result].valid?,
                "errors" => r[:result].errors }
            })
          else
            results.each do |r|
              status = r[:result].valid? ? "OK" : "FAIL"
              puts "[#{status}] #{r[:skill].id}"
              r[:result].errors.each { |e| puts "      #{e}" }
            end
            puts all_valid ? "\nAll skills valid." : "\nSome skills have errors."
          end

          exit 1 unless all_valid
        end

        def diff(skill_id, workspace_path = Dir.pwd)
          differ = ::Taskmate::Skills::Differ.new(workspace_path: workspace_path)
          result = differ.diff(skill_id)

          if fmt == "json"
            require "json"
            puts JSON.pretty_generate(
              "skill_id" => skill_id,
              "status"   => result.status.to_s,
              "diff"     => result.diff_text
            )
          else
            case result.status
            when :no_changes
              puts "No changes in #{skill_id} (matches built-in)"
            when :modified
              puts "#{skill_id} differs from built-in:\n\n#{result.diff_text}"
            when :custom
              puts "#{skill_id} is a custom skill (no built-in to compare)"
            end
          end
        end

        private

        def fmt
          @options[:format].to_s
        end

        def validate_format!
          unless VALID_FORMATS.include?(fmt)
            raise Taskmate::ValidationError, "Invalid format '#{fmt}'. Valid: #{VALID_FORMATS.join(", ")}"
          end
        end

        def skill_summary(skill)
          { "id" => skill.id, "version" => skill.version.to_s, "kind" => skill.kind }
        end

        def skill_detail(skill)
          {
            "id"          => skill.id,
            "version"     => skill.version.to_s,
            "kind"        => skill.kind,
            "description" => skill.description,
            "requires_ai" => skill.requires_ai,
            "inputs"      => skill.inputs,
            "outputs"     => skill.outputs,
            "security"    => skill.security
          }
        end
      end
    end
  end
end
