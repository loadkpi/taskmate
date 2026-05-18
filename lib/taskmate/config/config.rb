module Taskmate
  module Config
    TrackerConfig  = Data.define(:base_url, :default_project, :story_points_field)
    JiraAuthConfig = Data.define(:email, :api_token)
    AiConfig       = Data.define(:provider, :model, :enabled)
    SecurityConfig = Data.define(:require_consent_for_ai, :require_confirm_for_push, :secret_detection)
    PushConfig     = Data.define(:allowed_fields)
    AppConfig      = Data.define(:tracker, :auth, :ai, :security, :push)
  end
end
