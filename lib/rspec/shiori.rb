# frozen_string_literal: true

require 'fileutils'
require 'digest/md5'
require 'rspec'
require_relative "shiori/version"

class RspecShiori
  def initialize(example, cache_dir:)
    @example = example
    @cache_dir = cache_dir
    FileUtils.mkdir_p(@cache_dir)
    @call_stack = []
  end

  def trace
    tp = TracePoint.new(:call, :line, :return) do |t|
      case t.event
      when :call
        @call_stack << {
          event: :call,
          class: t.defined_class,
          method: t.method_id,
          path: t.path,
          lineno: t.lineno
        }
      when :return
        @call_stack << {
          event: :return,
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

  def cache_file_path
    digest = Digest::MD5.hexdigest(@example.metadata[:absolute_file_path])
    "#{@cache_dir}/#{digest}.json"
  end

  def cache
    path = cache_file_path
    return {} unless File.exists?(path)

    str = File.read(path)
    JSON.parse(str)
  end

  def cache!
    cache_hash = cache

    line_number = @example.metadata[:line_number].to_s
    cache_hash['line_number'] ||= {}
    cache_hash['line_number'][line_number] ||= {}

    cache_hash['line_number'][line_number]['rubyversion'] = RUBY_VERSION

    files = call_stack_files
    cache_hash['line_number'][line_number]['files'] = files_digest(files)

    File.write(cache_file_path, cache_hash.to_json)
  end

  def skip?
    cache_hash = cache
    line_number = @example.metadata[:line_number].to_s
    return false if cache_hash.dig('line_number', line_number, 'rubyversion') != RUBY_VERSION

    example_cache = cache_hash.dig('line_number', line_number, 'files')
    return false if example_cache.nil?

    example_cache.each do |path, digest|
      return false if digest != Digest::MD5.file(path).hexdigest
    end

    true
  rescue
    false
  end

  private

  def call_stack_files
    files = @call_stack.map { |entry| entry[:path] }
      .reject{|path|path.match(/\<.*?\>/)}
      .reject{|path|path.match(/\(.*?\)/)}
      .reject{|path|path.match(/\/.rbenv\//)}
    files << @example.metadata[:absolute_file_path]
    files.sort.uniq
  end

  def files_digest(files)
    hash = {}
    files.each do |file|
      hash[file] = Digest::MD5.file(file).hexdigest
    end
    hash
  end
end

RSpec.configuration.around(:each) do |example|
  @shiori = RspecShiori.new(example, cache_dir: 'tmp/shiori')
  if @shiori.skip?
    example.skip
  else
    @shiori.trace do
      example.run
    end
    @shiori.cache!
  end
end
