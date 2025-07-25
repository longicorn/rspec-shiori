# frozen_string_literal: true

require 'digest/md5'

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
