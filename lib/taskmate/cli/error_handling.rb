module Taskmate
  module CLI
    module ErrorHandling
      def with_taskmate_errors
        yield
      rescue Taskmate::ConsentDeniedError
        exit 0
      rescue Taskmate::ConflictError => e
        warn "Conflict: #{e.message}"
        exit 3
      rescue Taskmate::ValidationError => e
        warn "Validation error: #{e.message}"
        exit 2
      rescue Taskmate::JiraAuthError => e
        warn "Authentication failed: #{e.message}\nCheck TASKMATE_JIRA_EMAIL and TASKMATE_JIRA_TOKEN."
        exit 4
      rescue Taskmate::IssueNotFoundError, Taskmate::Error => e
        warn "Error: #{e.message}"
        exit 1
      end
    end
  end
end
