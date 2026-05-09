require "taskmate/skills/loader"
require "taskmate/security/audit_writer"

module Taskmate
  module Skills
    class Runner
      RunResult = Struct.new(:skill_id, :response_text, :prompt_hash, keyword_init: true)

      def initialize(workspace_path:, ai_provider:, security_policy:)
        @workspace_path  = workspace_path
        @ai_provider     = ai_provider
        @security_policy = security_policy
        @loader          = Loader.new(workspace_path: workspace_path)
      end

      # Run a skill against an issue file with optional user instruction.
      # Returns RunResult or raises ConsentDeniedError if user denied consent.
      def run(skill_id:, issue_file:, model: nil, instruction: nil)
        skill = @loader.load(skill_id)

        consent = @security_policy.authorize_ai_call(
          issue_file: issue_file,
          provider: @ai_provider.class.name,
          model: model,
          _skill: skill_id
        )

        raise ConsentDeniedError, "AI call denied for skill #{skill_id}" if consent == :deny

        prompt = build_prompt(skill, issue_file, instruction)
        response = @ai_provider.complete(prompt: prompt, skill_id: skill_id, model: model)

        prompt_hash = Security::AuditWriter.prompt_hash(prompt)

        @security_policy.write_ai_audit(
          skill: skill_id,
          provider: @ai_provider.class.name,
          model: model.to_s,
          prompt_hash: prompt_hash,
          issue_key: issue_file.key
        )

        RunResult.new(
          skill_id: skill_id,
          response_text: response,
          prompt_hash: prompt_hash
        )
      end

      private

      def build_prompt(skill, issue_file, instruction)
        parts = [skill.prompt_body]
        parts << "\n# Issue Content\n\n#{issue_file.raw_content}" if issue_file
        parts << "\n# User Instruction\n\n#{instruction}" if instruction && !instruction.strip.empty?
        parts.join("\n")
      end
    end
  end
end
