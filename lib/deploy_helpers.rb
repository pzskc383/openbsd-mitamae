require 'open3'
require "hashie"
require 'yaml'

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

  def self.host_list
    Dir.glob("data/hosts/*").map { |x| x.gsub!(%r{.*/}, '') }
  end

  def self.var_data
    self.load_config_dir("./data/vars")
  end

  def self.host_data(hostname)
    host_dir = "./data/hosts/#{hostname}"
    abort "Host directory #{host_dir} not found!" unless Dir.exist? host_dir
    self.load_config_dir(host_dir)
  end

  def self.host_ssh_target(hostname)
    host_data = host_data(hostname)
    host_data.dig("ssh_options", "target") || "root@#{hostname}"
  end

  def self.full_host_data(hostname)
    data_base = host_data(hostname)
    data_vars = {
      properties: {
        attributes: var_data
      }
    }
    data_other = {
      properties: {
        attributes: {
          hosts: other_hosts_data(hostname)
        }
      }
    }

    with_vars = deep_merge(data_base, data_vars)
    with_hosts = deep_merge(with_vars, data_other)
  end

  def self.other_hosts_data(current_host)
    host_list.reject { |h| h == current_host }.map do |other_host|
      other_attrs = host_data(other_host).dig('properties', 'attributes') || {}

      [
        other_host.to_sym,
        {
          dns_shortname: other_attrs[:dns_shortname],
          v4: other_attrs.dig('network_setup', 'v4', 'address'),
          v6: other_attrs.dig('network_setup', 'v6', 'address'),
        }
      ]
    end.to_h
  end

  def self.load_config_dir(directory)
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
    merged = loaded.reduce({}) { |acc, data| deep_merge(acc, data) }
    ::Hashie::Mash.quiet(:keys).new(merged)
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
