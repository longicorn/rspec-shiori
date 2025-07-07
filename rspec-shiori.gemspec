# frozen_string_literal: true

require_relative "lib/rspec/shiori/version"

Gem::Specification.new do |spec|
  spec.name = "rspec-shiori"
  spec.version = Rspec::Shiori::VERSION
  spec.authors = ["longicorn"]
  spec.email = ["longicorn.c@gmail.com"]

  spec.summary = "A gem to speed up RSpec test execution by caching previous test results."
  spec.description = "RSpec Shiori enhances the RSpec testing framework by caching the results of previous test executions and skipping tests that have not changed. This significantly reduces the execution time of RSpec runs, allowing developers to focus on the tests that matter without redundant execution."
  spec.homepage = "https://github.com/longicorn/rspec-shiori"
  spec.license = "Apache License 2.0"
  spec.required_ruby_version = ">= 3.0.0"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rspec"
end
