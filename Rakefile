require "bundler"
Bundler.setup(:default, :development)

require 'English'
require "open3"
require "pathname"
require "yaml"

require "pry"

require_relative "lib/deploy_helpers"
require_relative "lib/rake_logger"

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:cop) do |task|
  task.options << '--display-cop-names'
end

def log
  RakeLogger.instance
end

def log_cmd(*cmd)
  log.debug "=> #{cmd.join(' ')}"
end

def run_cmd(*cmd)
  log_cmd(*cmd)
  system(*cmd)
end

def git_submodule_reinit(path)
  sh "git submodule update --init --recursive --force --remote #{path}"
end

MITAMAE_DIR = "/etc/mitamae".freeze
MITAMAE_PATH = "/usr/local/sbin/mitamae"
BASE_YAML = "#{MITAMAE_DIR}/data/base.yaml".freeze
RUNTIME_YAML = "#{MITAMAE_DIR}/data/runtime.yaml".freeze

def bootstrap_host(hostname, verbose: false)
  ssh_target = DeployHelpers.host_ssh_target(hostname)

  if verbose
    log.level = Logger::DEBUG
  end

  try_bootstrap_host(ssh_target, verbose: verbose)
end

def try_bootstrap_host(ssh_target, verbose: false)
  test_cmd = "test -x #{MITAMAE_PATH}"
  run_cmd('ssh', ssh_target, test_cmd)
  return if $CHILD_STATUS.success?

  detect_cmd = ['ssh', ssh_target, 'uname -s; uname -m']
  log_cmd(*detect_cmd) if verbose
  target_os, target_arch = IO.popen(detect_cmd, 'r') do |cmd|
    cmd.read.downcase.split("\n")
  end
  log.debug("OS: #{target_os}, ARCH: #{target_arch}") if verbose
  abort "Failure detecting OS and arch!" unless $CHILD_STATUS.success?

  distname = "mitamae-#{target_arch}-#{target_os}"
  distpath = "./misc/dist/#{distname}"
  abort "Can't find mitamae dist #{distname} locally!" unless File.exist?(distpath)

  install_cmd_str = <<~CMD.squeeze(' ')
    cat > /tmp/mitamae && \
    install -g wheel -o root -m 0755 /tmp/mitamae #{MITAMAE_PATH} && \
    rm -f /tmp/mitamae
  CMD

  log.info("Bootstrapping mitamae for #{target_os}/#{target_arch} on #{ssh_target}")
  IO.popen(["ssh", ssh_target, install_cmd_str], "w") do |cmd|
    cmd.write(File.read(distpath))
  end
  abort "Failure uploading mitamae binary!" unless $CHILD_STATUS.success?
end

def apply_host(hostname, dry_run: false, verbose: false)
  host_config = DeployHelpers.full_host_data(hostname)

  run_list = host_config.dig("properties", "run_list") || []
  abort "No run_list defined for #{hostname}" if run_list.empty?

  ssh_target = DeployHelpers.host_ssh_target(hostname)

  if verbose
    log.level = Logger::DEBUG
  end

  try_bootstrap_host(ssh_target, verbose)

  data_subdirs = %w[plugins cookbooks]
  local_cmd = %w[tar -cf -] + data_subdirs
  remote_cmd = "mkdir -p #{MITAMAE_DIR} && cd #{MITAMAE_DIR} && rm -rf #{data_subdirs.join(' ')} && tar -xf -"
  upload_cmd = ["ssh", ssh_target, remote_cmd]

  log.info("Uploading new cookbooks")
  if verbose
    log_cmd(local_cmd)
    log_cmd(upload_cmd)
  end
  IO.popen(upload_cmd, "w") do |ssh_stdin|
    IO.popen(local_cmd) do |tar_stdout|
      ssh_stdin.write(tar_stdout.read)
    end
  end
  abort "Failed to upload files" unless $CHILD_STATUS.success?


  log.info("Rendering base.yaml and default runtime.yaml")
  host_attributes = host_config.dig('properties', 'attributes')
  base_yaml_cmd = <<~CMD
    test -d #{MITAMAE_DIR}/data || mkdir -p #{MITAMAE_DIR}/data
    test -f #{RUNTIME_YAML} || { echo '--- {}'; echo; } > #{RUNTIME_YAML}
    cat > #{BASE_YAML}
    chmod 400 #{BASE_YAML}
    chmod 600 #{RUNTIME_YAML}
  CMD

  attr_cmd = ["ssh", ssh_target, base_yaml_cmd]
  log_cmd(attr_cmd) if verbose
  IO.popen(attr_cmd, "w") do |cmd|
    cmd.write(YAML.dump(host_attributes))
  end
  abort "Failed to write base.yaml" unless $CHILD_STATUS.success?

  mitamae_opts = ""
  mitamae_opts += "-n" if dry_run
  if verbose
    mitamae_opts += "--log-level debug" if verbose
  end

  mitamae_cmd = <<~CMD.squeeze(' ')
    cd #{MITAMAE_DIR} && \
      #{MITAMAE_PATH} local #{mitamae_opts} \
        -y data/base.yaml -y data/runtime.yaml \
        cookbooks/defines.rb #{run_list.join(' ')}
  CMD

  log.info("Launching mitamae apply")
  run_cmd("ssh", ssh_target, mitamae_cmd)
end

namespace :prepare do
  desc "set up working environment (cron plugin + dist binaries + project notes)"
  task :deps do
    git_submodule_reinit "plugins/mitamae-plugin-resource-cron"
    git_submodule_reinit "plugins/mitamae-plugin-resource-openbsd_package"
    sh "git worktree add misc/dist dist" unless Dir.exist?("misc/dist")
    sh "git worktree add misc/notes notes" unless Dir.exist?("misc/notes")
    sh "rm -f AGENTS.md && ln -s misc/notes/CLAUDE.md AGENTS.md"
    sh "rm -f CLAUDE.md && ln -s misc/notes/CLAUDE.md CLAUDE.md"
  end

  desc "set up example repos"
  task :examples do
    %w[example-ruby-infra example-ruby-git sorah-cnw].each do |name|
      git_submodule_reinit "misc/examples/#{name}"
    end
  end

  desc "set up and compile mitamae sources"
  task :mitamae do
    git_submodule_reinit "misc/mitamae" unless Dir.exist?("misc/mitamae/mruby")
    sh "cd misc/mitamae && rake compile && git checkout ."
  end
end

namespace :hosts do
  desc "list defined hosts"
  task :list do
    DeployHelpers.host_list.each { |host| puts host }
  end

  desc "show host's merged config (usage: rake hosts:show[v1be])"
  task :show do |_t, args|
    hostname = args.extras.first or abort "Usage: rake hosts:show[hostname]"
    globals = DeployHelpers.load_config("./data/vars")
    host_config = DeployHelpers.load_config("./data/hosts/#{hostname}")
    merged = globals.merge(host_config)
  end
end

namespace :deploy do
  desc "bootstrap mitamae on host (usage: rake deploy:bootstrap[v1be])"
  task :bootstrap, [:host, :verbose] do |_t, args|
    bootstrap_host(args.host, verbose: !args.verbose.nil?)
  end

  desc "dry-run mitamae (usage: rake deploy:dry_run[v1be])"
  task :dry_run, [:host, :verbose] do |_t, args|
    apply_host(args.host, dry_run: true, verbose: !args.verbose.nil?)
  end

  desc "apply mitamae (usage: rake deploy:apply[v1be])"
  task :apply, [:host, :verbose] do |_t, args|
    apply_host(args.host, verbose: !args.verbose.nil?)
  end
end

namespace :mitamae do
  desc "run mitamae's mirb"
  task mirb: %w[prepare:mitamae] do
    sh "./misc/mitamae/mruby/bin/mirb"
  end
end

# shortcuts
task prepare: "prepare:deps"
task bootstrap: "deploy:bootstrap"
task dry_run: "deploy:dry_run"
task apply: "deploy:apply"
task mirb: "mitamae:mirb"
task list: "hosts:list"
task show: "hosts:show"
