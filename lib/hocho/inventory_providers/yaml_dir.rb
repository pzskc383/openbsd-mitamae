require 'yaml'
require 'open3'
require 'hocho/utils/symbolize'
require 'hocho/inventory_providers/base'
require 'hocho/host'

module Hocho
  module InventoryProviders
    class YamlDir < Base
      def initialize(path:)
        @path = path
        @vars_dir = File.join(File.dirname(@path), "vars")
        @global_attrs = load_global_vars!
        super()
      end

      attr_reader :path

      def load_file(filename)
        data =
          if filename.include?(".sops.yml")
            stdout, status = Open3.capture2("sops", "-d", filename)
            raise "SOPS decryption error for #{filename}" unless status.success?

            YAML.safe_load(stdout, aliases: true).except(:sops)
          else
            YAML.load_file(filename, aliases: true)
          end

        Hocho::Utils::Symbolize.keys_of(data)
      end

      def load_dir_vars(path)
        files = Dir[File.join(path, "*.yml")].sort_by do |fn|
          basename = File.basename(fn)
          if basename == "default.yml"
            [0, basename]
          elsif fn.include?(".sops.yml")
            [2, basename]
          else
            [1, basename]
          end
        end

        files.map { |f| load_file(f) }.reduce({}) { |acc, data| deep_merge(acc, data) }
      end

      def deep_merge(hash1, hash2)
        hash1.merge(hash2) { |_k, v1, v2| v1.is_a?(Hash) && v2.is_a?(Hash) ? deep_merge(v1, v2) : v2 }
      end

      def build_hosts_data(loaded_hosts)
        data = {}

        loaded_hosts.each do |name, value|
          attrs = value.dig(:properties, :attributes) || {}
          net = attrs[:network_setup] || {}
          data[name] = {
            dns_shortname: attrs[:dns_shortname],
            v4: net.dig(:v4, :address),
            v6: net.dig(:v6, :address)
          }
        end

        data
      end

      def hosts
        @hosts ||= begin
          host_dirs = Dir[File.join(@path, "*/")]
          loaded_hosts = host_dirs.to_h do |dir|
            name = File.basename(dir)
            value = load_dir_vars(dir)
            [name, value]
          end

          hosts_data = build_hosts_data(loaded_hosts)

          loaded_hosts.map do |name, value|
            props = value[:properties] || {}
            attrs = props.fetch(:attributes, {}).dup

            attrs.merge!(@global_attrs)

            attrs[:hosts] = hosts_data
            attrs[:hostname] = name

            props[:attributes] = attrs

            Host.new(
              name.to_s,
              providers: self.class,
              properties: props,
              tags: value[:tags] || {},
              ssh_options: value[:ssh_options]
            )
          end
        end
      end

      private

      def load_global_vars!
        load_dir_vars(@vars_dir)
      end
    end
  end
end
