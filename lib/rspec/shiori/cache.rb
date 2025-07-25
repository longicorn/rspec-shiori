# frozen_string_literal: true

require 'fileutils'

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
