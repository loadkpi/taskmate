module Taskmate
  module Skills
    Skill = Struct.new(
      :id, :version, :kind, :description, :requires_ai,
      :inputs, :outputs, :security,
      :source, :builtin_version, :source_hash,
      :prompt_body, :path,
      keyword_init: true
    )
  end
end
