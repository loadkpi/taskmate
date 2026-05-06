require "taskmate/ai/ai_port"

module Taskmate
  module AI
    module Providers
      class FakeProvider
        include AiPort

        Call = Struct.new(:prompt, :skill_id, :model, keyword_init: true)

        class SimulatedError < Error; end

        def initialize(responses: {}, default_response: nil, error_for: [])
          @responses        = responses        # { skill_id => response_text }
          @default_response = default_response || "Fake AI response."
          @error_for        = Array(error_for) # skill_ids that should raise
          @calls            = []
        end

        def complete(prompt:, skill_id:, model: nil)
          @calls << Call.new(prompt: prompt, skill_id: skill_id, model: model)

          if @error_for.include?(skill_id)
            raise SimulatedError, "Simulated AI error for skill: #{skill_id}"
          end

          @responses.fetch(skill_id, @default_response)
        end

        attr_reader :calls

        def call_count
          @calls.size
        end

        def last_call
          @calls.last
        end

        def called_with_skill?(skill_id)
          @calls.any? { |c| c.skill_id == skill_id }
        end
      end
    end
  end
end
