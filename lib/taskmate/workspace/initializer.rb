require "fileutils"
require "yaml"

module Taskmate
  module Workspace
    DIRECTORIES = %w[
      issues
      issues/new
      issues/conflicts
      issues/.jira
      reviews
      estimates
      planning
      metrics
      skills
      audit
      audit/actions
      audit/ai
    ].freeze

    TASKMATEIGNORE_CONTENT = <<~IGNORE.freeze
      # Taskmate ignore file (gitignore-like syntax)
      # Files matching these patterns will not be sent to AI

      # Private keys and certificates
      *.key
      *.pem
      *.p12

      # Secret files
      secrets.yml
      secrets.yaml
      .env
      .env.*

      # Attachments / binaries
      attachments/
      *.pdf
      *.zip
      *.tar.gz
    IGNORE

    class Initializer
      def initialize(workspace_path:, interactive: true, prompt: nil)
        @workspace_path = workspace_path
        @interactive = interactive
        @prompt = prompt
      end

      def call
        result = {
          created_dirs: [],
          existing_dirs: [],
          workspace_yml_created: false,
          taskmateignore_created: false,
          skills_copied: false
        }

        if workspace_yml_exists?
          result[:workspace_yml_exists] = true
        else
          config = interactive? ? ask_config : default_config
          write_workspace_yml(config)
          result[:workspace_yml_created] = true
        end

        DIRECTORIES.each do |dir|
          full_path = File.join(@workspace_path, dir)
          if Dir.exist?(full_path)
            result[:existing_dirs] << dir
          else
            FileUtils.mkdir_p(full_path)
            result[:created_dirs] << dir
          end
        end

        unless File.exist?(taskmateignore_path)
          File.write(taskmateignore_path, TASKMATEIGNORE_CONTENT)
          result[:taskmateignore_created] = true
        end

        result[:skills_copied] = copy_builtin_skills

        result
      end

      private

      def workspace_yml_exists?
        File.exist?(File.join(@workspace_path, "workspace.yml"))
      end

      def taskmateignore_path
        File.join(@workspace_path, ".taskmateignore")
      end

      def interactive?
        @interactive
      end

      def ask_config
        return default_config unless @prompt

        jira_url = @prompt.ask("Jira base URL (e.g. https://your-org.atlassian.net):", default: "")
        project_key = @prompt.ask("Default project key (e.g. SAR):", default: "")
        ai_provider = @prompt.select(
          "AI provider:",
          %w[disabled openai anthropic ollama],
          default: "disabled"
        )

        @prompt.say("Remember to set the corresponding ENV variable for your provider.") if ai_provider != "disabled"

        build_config(jira_url: jira_url, project_key: project_key, ai_provider: ai_provider)
      end

      def default_config
        build_config(jira_url: "", project_key: "", ai_provider: "disabled")
      end

      def build_config(jira_url:, project_key:, ai_provider:)
        {
          "version" => 1,
          "tracker" => {
            "kind" => "jira",
            "base_url" => jira_url,
            "default_project" => project_key
          },
          "ai" => {
            "provider" => ai_provider,
            "model" => ""
          },
          "security" => {
            "require_consent_for_ai" => true,
            "require_confirm_for_push" => true,
            "secret_detection" => true,
            "store_prompts_in_audit" => false
          },
          "push" => {
            "allowed_fields" => %w[summary description labels components priority]
          }
        }
      end

      def write_workspace_yml(config)
        path = File.join(@workspace_path, "workspace.yml")
        File.write(path, YAML.dump(config))
      end

      # Returns :copied, :already_present, or :unavailable
      def copy_builtin_skills
        builtins_dir = File.join(File.dirname(__FILE__), "..", "skills", "builtins")
        return :unavailable unless Dir.exist?(builtins_dir)

        skills_dir = File.join(@workspace_path, "skills")
        FileUtils.mkdir_p(skills_dir)

        copied = false
        Dir.glob(File.join(builtins_dir, "*")).each do |skill_dir|
          next unless File.directory?(skill_dir)

          dest = File.join(skills_dir, File.basename(skill_dir))
          unless Dir.exist?(dest)
            FileUtils.cp_r(skill_dir, dest)
            copied = true
          end
        end
        copied ? :copied : :already_present
      end
    end
  end
end
