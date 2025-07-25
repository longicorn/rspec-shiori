# frozen_string_literal: true

require 'rspec'

def RSpec.shiori
  @shiori ||= RspecShiori.new(cache_dir: 'tmp/cache/shiori')
end

RSpec.configuration.before(:suite) do |config|
  RSpec.shiori.disable = !(['1', 'true'].include?(ENV['SHIORI']))
  RSpec.shiori.read_cache(:file)
end

RSpec.configuration.around(:each) do |example|
  RSpec.shiori.read_cache(:spec, example)
  RSpec.shiori.spec(example) do |shiori_spec|
    if shiori_spec.skip? && example.metadata[:shiori] != false
      example.execution_result.pending_fixed = true
      example.execution_result.pending_message = 'skipped by rspec-shiori'
      example.run
      next
    end

    shiori_spec.trace do
      example.run
    end

    shiori_spec.memory_cache
    @spec_cache = shiori_spec.spec_cache
    @files_cache = shiori_spec.files_cache
  end
end

RSpec.configuration.after(:suite) do |config|
  RSpec.shiori.write_cache
end
