require_relative "taskmate/version"
require_relative "taskmate/config"

module Taskmate
  class Error < StandardError; end

  # Config/setup
  class ConfigError < Error; end
  class WorkspaceNotFoundError < Error; end

  # Workspace
  class IssueNotFoundError < Error; end
  class InvalidFrontmatterError < Error; end
  class ValidationError < Error; end

  # Sync
  class ConflictError < Error; end
  class SyncError < Error; end

  # Security
  class ConsentDeniedError < Error; end
  class SecretDetectedError < Error; end

  # External
  class JiraError < Error; end
  class JiraAuthError < JiraError; end
  class JiraNotFoundError < JiraError; end
  class JiraRateLimitError < JiraError; end
  class JiraWriteError < JiraError; end

  class AiError < Error; end
  class AiAuthError < AiError; end
  class AiProviderError < AiError; end
end
