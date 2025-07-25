# frozen_string_literal: true

require 'digest/md5'
require_relative 'shiori/example'
require_relative 'shiori/cache'
require_relative 'shiori/version'
require_relative 'shiori/hook'

class RspecShiori
  def initialize(cache_dir:)
    @cache_dir = cache_dir
    @cache = Cache.new(cache_dir)
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
