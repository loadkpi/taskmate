module Taskmate
  module Security
    class SecretRedactor
      SecretMatch = Struct.new(:type, :position, :length, :severity, keyword_init: true)

      PATTERNS = [
        { type: :jwt,           severity: :high,
          regex: /\bey[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b/ },
        { type: :bearer_token,  severity: :high,
          regex: /\bBearer\s+[A-Za-z0-9\-._~+\/]+=*(?=\s|$|[^A-Za-z0-9\-._~+\/=])/i },
        { type: :basic_auth,    severity: :high,
          regex: /\bBasic\s+[A-Za-z0-9+\/]+=*(?=\s|$|[^A-Za-z0-9+\/=])/i },
        { type: :aws_key,       severity: :critical,
          regex: /\bAKIA[0-9A-Z]{16}\b/ },
        # AWS secret access keys only in explicit key=value context to avoid false positives
        { type: :aws_secret,    severity: :critical,
          regex: /(?:aws_secret_access_key|AWS_SECRET_ACCESS_KEY)\s*[:=]\s*["']?[A-Za-z0-9\/+]{40}["']?/ },
        { type: :github_token,  severity: :high,
          regex: /\bgh[pousr]_[A-Za-z0-9]{36,}\b/ },
        { type: :gitlab_token,  severity: :high,
          regex: /\bglpat-[A-Za-z0-9\-_]{20,}\b/ },
        { type: :private_key,   severity: :critical,
          regex: /-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY(?:-----| BLOCK-----)/ },
        { type: :url_credentials, severity: :high,
          regex: %r{https?://[^@\s/]+:[^@\s/]+@[^\s]+} },
        { type: :generic_secret, severity: :medium,
          regex: /(?:password|passwd|secret|api[_-]?key|token)\s*[:=]\s*["']?[A-Za-z0-9\-_\/+.]{8,}["']?/i }
      ].freeze

      REDACTED = "[REDACTED]"

      def scan(text)
        return [] if text.nil? || text.empty?

        matches = []
        PATTERNS.each do |pattern|
          text.scan(pattern[:regex]) do
            m = Regexp.last_match
            matches << SecretMatch.new(
              type:     pattern[:type],
              position: m.begin(0),
              length:   m[0].length,
              severity: pattern[:severity]
            )
          end
        end
        matches.sort_by(&:position)
      end

      def secrets_found?(text)
        PATTERNS.any? { |p| p[:regex].match?(text.to_s) }
      end

      def redact(text)
        return text.to_s if text.nil? || text.empty?

        result = text.dup
        # Process patterns from most specific/critical to least to avoid
        # over-redacting context that would hide other secrets
        PATTERNS.each do |pattern|
          result = result.gsub(pattern[:regex], REDACTED)
        end
        result
      end
    end
  end
end
