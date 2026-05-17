require_relative "lib/taskmate/version"

Gem::Specification.new do |spec|
  spec.name          = "taskmate"
  spec.version       = Taskmate::VERSION
  spec.authors       = ["Pavel Kozlov"]
  spec.email         = ["loadkpi@gmail.com"]

  spec.summary       = "Secure-by-default, local-first AI assistant for managing issue tracker tasks"
  spec.description   = "Taskmate turns your issue tracker into a local Git-friendly workspace: " \
                       "tasks are stored as Markdown/YAML files you can read, edit in IDE, " \
                       "commit to Git, and sync back with explicit confirmation."
  spec.homepage      = "https://github.com/taskmate-dev/taskmate"
  spec.license       = "MIT"
  spec.metadata      = {
    "source_code_uri" => "https://github.com/taskmate-dev/taskmate",
    "changelog_uri" => "https://github.com/taskmate-dev/taskmate/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.required_ruby_version = ">= 3.3"

  spec.files = Dir[
    "lib/**/*.rb",
    "lib/**/*.md",
    "lib/**/*.yml",
    "lib/**/*.yaml",
    "exe/*",
    "*.md",
    "LICENSE"
  ]

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.12"
  spec.add_dependency "faraday-retry", "~> 2.2"
  spec.add_dependency "pastel", "~> 0.8"
  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "tty-prompt", "~> 0.23"
  spec.add_dependency "tty-spinner", "~> 0.9"
  spec.add_dependency "tty-table", "~> 0.12"
end
