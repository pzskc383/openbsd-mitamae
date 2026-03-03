require 'open3'
require 'yaml'
require 'hashie'

module DeployHelpers
  def self.deep_merge(base, overlay)
    base.merge(overlay) do |_key, base_val, overlay_val|
      if base_val.is_a?(Hash) && overlay_val.is_a?(Hash)
        deep_merge(base_val, overlay_val)
      else
        overlay_val
      end
    end
  end

  def self.load_config(directory)
    files = Dir.glob("#{directory}/*.yml").sort_by do |fn|
      basename = File.basename(fn)
      if basename == "default.yml"
        [0, basename]
      elsif fn.include?(".sops.yml")
        [2, basename]
      else
        [1, basename]
      end
    end

    loaded = files.map { |f| load_yaml(f) }
    loaded.reduce({}) { |acc, data| deep_merge(acc, data) }
  end

  def self.load_yaml(path)
    return {} unless File.exist?(path)

    if path.end_with?('.sops.yml')
      begin
        stdout, status = Open3.capture2('sops', '-d', path)
        raise "SOPS failed" unless status.success?

        YAML.safe_load(stdout) || {}
      rescue StandardError => e
        warn "Failed to decrypt #{path}: #{e.message}"
        {}
      end
    else
      YAML.safe_load_file(path) || {}
    end
  rescue StandardError => e
    warn "Failed to load #{path}: #{e.message}"
    {}
  end
end
