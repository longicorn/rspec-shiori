# frozen_string_literal: true

require 'fileutils'
require 'digest/md5'
require 'rspec'
require_relative "shiori/version"

class RspecShioriCache
  def initialize(cache_dir)
    @cache_dir = cache_dir
    FileUtils.mkdir_p(@cache_dir)
  end

  def read(path)
    return {} unless File.exist?(path)

    str = File.read(path)
    JSON.parse(str)
  end

  def write(path, hash)
    str = JSON.dump(hash)
    File.write(path, str)
  end
end

class RspecShiori
  class Example
    def initialize(example, files_cache:, spec_cache:)
      @example = example
      @files_cache = files_cache
      @spec_cache = spec_cache
      @call_stack = []
    end
    attr_reader :files_cache, :spec_cache

    def trace
      tp = TracePoint.new(:call) do |t|
        next if tp.path.include?('/ruby/') && tp.path.include?('/gems/')

        case t.event
        when :call
          @call_stack << {
            event: :call,
            class: t.defined_class,
            method: t.method_id,
            path: t.path,
            lineno: t.lineno
          }
        end
      end

      tp.enable
      yield
      tp.disable
    end

    def skip?
      Gem.loaded_specs.each do |name, spec|
        # gems is changed
        return false unless @files_cache['gems'][name] == spec.version.to_s
      end

      example_path = @example.metadata[:absolute_file_path]
      line_number = @example.metadata[:line_number].to_s

      # test not executed
      cache = @spec_cache[example_path]
      return false unless cache

      # test not execution of line_number
      return false unless cache.dig('line_number', line_number)
      cache['line_number'] ||= {}
      cache['line_number'][line_number] ||= {}

      # different ruby version
      return false if cache['line_number'][line_number]['rubyversion'] != RUBY_VERSION

      # tested but not successful
      return false if cache['line_number'][line_number]['result'] != true

      cache['line_number'][line_number]['files'].each do |file|
        # file is not include on latest tested
        return false unless @files_cache['files'][file]
        # file is changed on latest tested
        return false if @files_cache['files'][file]['changed'] != true
      end

      true
    end

    def memory_cache
      @spec_cache ||= {}
      example_path = @example.metadata[:absolute_file_path]
      cache = @spec_cache[example_path]

      line_number = @example.metadata[:line_number].to_s
      cache['line_number'] ||= {}
      cache['line_number'][line_number] ||= {}
      cache['line_number'][line_number]['rubyversion'] = RUBY_VERSION
      cache['line_number'][line_number]['result'] = @example.exception ? false : true

      cache['line_number'][line_number]['files'] ||= []
      call_stack_files.each do |file|
        cache['line_number'][line_number]['files'] << file
        unless @files_cache['files'][file]
          @files_cache['files'][file] = {}
          hexdigest = Digest::MD5.file(file).hexdigest
          @files_cache['files'][file]['digest'] = hexdigest
          @files_cache['files'][file]['changed'] = 'first'
        end
      end
      cache['line_number'][line_number]['files'].uniq!

      @spec_cache[example_path] = cache
    end

    private

    def call_stack_files
      files = @call_stack.map { |entry| entry[:path] }
        .reject{|path|path.match(/\<.*?\>/)}
        .reject{|path|path.match(/\(.*?\)/)}
        .reject{|path|path.match(/\/.rbenv\//)}
        .reject{|path|path.include?('/ruby/') && path.include?('/gems/')}
      files << @example.metadata[:absolute_file_path]
      files.sort.uniq
    end
  end
end

class RspecShiori
  def initialize(cache_dir:)
    @cache_dir = cache_dir
    @cache = RspecShioriCache.new(cache_dir)
    @disable = true
  end
  attr_accessor :disable

  def spec(example)
    if @disable
      example.run
    else
      exp = Example.new(example, files_cache: @files_cache, spec_cache: @spec_cache)
      yield exp
    end
  end

  def read_cache(key, example = nil)
    return if @disable

    case key
    when :file
      @files_cache = {}
      @files_cache['gems'] = {}
      @files_cache['files'] = {}
      cache = @cache.read("#{@cache_dir}/file.json")
      cache['gems']&.each do |name, version|
        @files_cache['gems'][name] = version
      end
      cache['files']&.each do |path, hexdigest|
        @files_cache['files'][path] = {}
        current_digest = Digest::MD5.file(path).hexdigest
        @files_cache['files'][path]['digest'] = current_digest
        @files_cache['files'][path]['changed'] = (current_digest == hexdigest)
      end
    when :spec
      @spec_cache ||= {}
      example_path = example.metadata[:absolute_file_path]
      path_digest = Digest::MD5.hexdigest(example_path)
      @spec_cache[example_path] ||= @cache.read("#{@cache_dir}/#{path_digest}.json")
    end
  end

  def write_cache
    return if @disable

    files_cache = {}
    files_cache['gems'] = {}
    Gem.loaded_specs.each do |name, spec|
      files_cache['gems'][name] = spec.version.to_s
    end
    files_cache['files'] = {}
    @files_cache['files'].each do |path, hash|
      files_cache['files'][path] = hash['digest']
    end
    File.write("#{@cache_dir}/file.json", JSON.dump(files_cache))

    @spec_cache.each do |path, hash|
      path_digest = Digest::MD5.hexdigest(path)
      File.write("#{@cache_dir}/#{path_digest}.json", JSON.dump(hash))
    end
  end
end

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
