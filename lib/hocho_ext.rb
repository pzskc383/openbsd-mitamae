# Monkey-patches for hocho to support OpenBSD (sh instead of bash, configurable sudo)

require "hocho/drivers/mitamae"
require "hocho/drivers/ssh_base"

module HochoOpenBSDPatches
  module MitamaePatches
    def prepare_mitamae
      return if mitamae_available? && !mitamae_outdated?

      script = [*@mitamae_prepare_script].join("\n\n")
      raise "We have to prepare MItamae, but not mitamae_prepare_script is specified" if script.empty?

      log_prefix = "=> #{host.name} # "
      log_prefix_white = " " * log_prefix.size
      puts "#{log_prefix}#{script.each_line.map {
        |line| "#{log_prefix_white}#{line.chomp}"
      }.join("\n")}"

      ssh_run("sh") do |cmd|
        set_ssh_output_hook(cmd)

        cmd.send_data("cd #{host_basedir.shellescape}\nsh <<-'HOCHOEOS'\n#{script}HOCHOEOS\n")
        cmd.eof!
      end

      availability = mitamae_available?
      outdated = mitamae_outdated?
      return unless !availability || outdated

      status = [availability ? nil : "unavailable", outdated ? "outdated" : nil].compact.join(" and ")
      raise "prepared MItamae, but it's still #{status}"
    end

    def run_mitamae(**kwopts)
      @mitamae_options.push('--dry-run') unless !!kwopts.dry_run

      with_host_node_json_file do
        itamae_cmd = [
          @mitamae_path,
          "local", "-j",
          host_node_json_path,
          *@mitamae_options,
        ].shelljoin

        puts "=> #{host.name} # #{itamae_cmd}"

        ssh_run("sh") do |shell|
          set_ssh_output_hook(shell)

          shell.send_data("cd #{host_basedir.shellescape}\n#{itamae_cmd}\n")
          shell.eof!
        end
      end
    end
  end

  module SshBasePatches
    def deploy(deploy_dir: nil, _shm_prefix: [])
      @host_basedir = deploy_dir if deploy_dir

      ssh_cmd = ['ssh', *host.openssh_config.flat_map { |option| ['-o', "\"#{option}\""] }].join(' ')

      hostname = host.hostname.then { |name| name.include?(':') ? "[#{name}]" : name }

      # Only include cookbooks lib and plugins directories
      rsync_cmd = [
        'rsync', '-a', '--copy-links', '--copy-unsafe-links', '--delete',
        '--rsh', ssh_cmd,
        'cookbooks', 'lib', 'plugins',
        "#{hostname}:#{host_basedir}"
      ]

      puts "=> $ #{rsync_cmd.shelljoin}"
      system(*rsync_cmd, chdir: base_dir) or raise 'failed to rsync'

      yield
    ensure
      if !deploy_dir || !keep_synced_files
        cmd = "rm -rf #{host_basedir.shellescape}"
        puts "=> #{host.name} $ #{cmd}"
        ssh_run(cmd, error: false)
      end
    end
  end
end

Hocho::Drivers::Mitamae.prepend(HochoOpenBSDPatches::MitamaePatches)
Hocho::Drivers::SshBase.prepend(HochoOpenBSDPatches::SshBasePatches)
