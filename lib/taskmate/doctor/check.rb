module Taskmate
  module Doctor
    class Check
      STATUSES = %i[ok fail skip].freeze

      attr_reader :name, :description, :status, :message

      def initialize(name:, description:)
        @name = name
        @description = description
        @status = :skip
        @message = nil
      end

      def run
        raise NotImplementedError, "#{self.class}#run must be implemented"
      end

      protected

      def ok!(message = nil)
        @status = :ok
        @message = message
      end

      def fail!(message)
        @status = :fail
        @message = message
      end

      def skip!(message = nil)
        @status = :skip
        @message = message
      end
    end
  end
end
