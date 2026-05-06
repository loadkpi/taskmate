module Taskmate
  module AI
    # Interface that all AI providers must implement.
    module AiPort
      # @param prompt [String]
      # @param skill_id [String]
      # @param model [String, nil]
      # @return [String] raw AI response text
      def complete(prompt:, skill_id:, model: nil)
        raise NotImplementedError, "#{self.class}#complete must be implemented"
      end
    end
  end
end
