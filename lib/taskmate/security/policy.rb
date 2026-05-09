require "taskmate/security/secret_redactor"
require "taskmate/security/data_classifier"
require "taskmate/security/consent_manager"
require "taskmate/security/action_gate"
require "taskmate/security/audit_writer"

module Taskmate
  module Security
    class Policy
      def initialize(workspace_path:, consent_manager: nil, action_gate: nil, # rubocop:disable Metrics/ParameterLists
                     audit_writer: nil, redactor: nil, classifier: nil,
                     non_interactive: false)
        @workspace_path  = workspace_path
        @non_interactive = non_interactive
        @redactor = redactor || SecretRedactor.new
        @classifier = classifier || DataClassifier.new(
          workspace_path: workspace_path,
          redactor: @redactor
        )
        @consent_manager = consent_manager || ConsentManager.new(
          non_interactive: non_interactive
        )
        @action_gate = action_gate || ActionGate.new(
          non_interactive: non_interactive
        )
        @audit_writer = audit_writer || AuditWriter.new(
          workspace_path: workspace_path
        )
      end

      # Orchestrates: ignore rules → redact → classify → consent
      # Returns :allow or :deny
      def authorize_ai_call(issue_file:, provider:, model: nil, _skill: nil)
        classification = @classifier.classify(issue_file)

        return :deny if classification.level == :excluded

        if classification.level == :secret
          warn "Blocked: secrets detected in issue content. Redact before using AI."
          return :deny
        end

        context = ConsentManager::ConsentContext.new(
          provider: provider,
          model: model,
          files: [issue_file.path].compact,
          sections: classification.sections.map { |s| "#{s.name} (#{s.level})" },
          excluded_paths: classification.excluded_paths
        )

        @consent_manager.request(context)
      end

      # Orchestrates: show plan → action gate
      # Returns :allow or :deny
      def authorize_jira_write(action_plan)
        @action_gate.confirm(action_plan)
      end

      # Delegate to AuditWriter
      def write_action_audit(**)
        @audit_writer.write_action_audit(**)
      end

      def write_ai_audit(**)
        @audit_writer.write_ai_audit(**)
      end
    end
  end
end
