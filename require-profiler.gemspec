# frozen_string_literal: true

require_relative "lib/require_profiler/version"

Gem::Specification.new do |s|
  s.name = "require-profiler"
  s.version = RequireProfiler::VERSION
  s.authors = ["Vladimir Dementyev"]
  s.email = ["Vladimir Dementyev"]
  s.homepage = "https://github.com/palkan/require-profiler"
  s.summary = "Profile Ruby #require/#load/etc calls"
  s.description = "Profile Ruby #require/#load/etc calls"

  s.metadata = {
    "bug_tracker_uri" => "https://github.com/palkan/require-profiler/issues",
    "changelog_uri" => "https://github.com/palkan/require-profiler/blob/master/CHANGELOG.md",
    "documentation_uri" => "https://github.com/palkan/require-profiler",
    "homepage_uri" => "https://github.com/palkan/require-profiler",
    "source_code_uri" => "https://github.com/palkan/require-profiler",
    "hyperdrive_targets" => "railties",
    "hyperdrive_artifacts" => "skill"
  }

  s.license = "MIT"

  s.files = Dir.glob("lib/**/*") + Dir.glob("bin/**/*") + Dir.glob("skills/**/*") +
    %w[README.md LICENSE.txt CHANGELOG.md hyperdrive.yml]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.1"

  s.add_dependency "require-hooks", "~> 0.3"

  s.add_development_dependency "bundler", ">= 1.15"
  s.add_development_dependency "benchmark"
  s.add_development_dependency "logger"
  s.add_development_dependency "railties", ">= 7.2"
  s.add_development_dependency "rake", ">= 13.0"
  s.add_development_dependency "rspec", ">= 3.9"
  s.add_development_dependency "sniffer"
  s.add_development_dependency "webmock", "~> 3.26"
end
