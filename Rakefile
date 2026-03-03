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

def host_list
  Pathname("./data/hosts").children.map do |path|
    path.basename.to_s
  end
end

def run_cmd(*cmd)
  log.debug "=> #{cmd.join(' ')}"
  system(*cmd) or abort "Command failed: #{cmd.first}"
end

def git_submodule_reinit(path)
  sh "git submodule update --init --recursive --force --remote #{path}"
end

def log
  RakeLogger.instance
end

MITAMAE_DIR = "/etc/mitamae".freeze
BASE_YAML = "#{MITAMAE_DIR}/data/base.yaml".freeze
RUNTIME_YAML = "#{MITAMAE_DIR}/data/runtime.yaml".freeze

def apply_host(hostname, dry_run: false, verbose: false)
  mitamae_opts = ""
  mitamae_opts += "-n" if dry_run
  if verbose
    mitamae_opts += "--log-level debug" if verbose
    log.level = Logger::DEBUG
  end

  host_config = DeployHelpers.load_config("./data/hosts/#{hostname}")
  attrs = host_config.dig("properties", "attributes")
  attrs.merge!(DeployHelpers.load_config("./data/vars"))

  run_list = host_config.dig("properties", "run_list") || []
  abort "No run_list defined for #{hostname}" if run_list.empty?

  ssh_target = host_config.dig("ssh_options", "target") || "root@#{hostname}"

  rsync_cmd = %w[rsync -av --delete --exclude data cookbooks lib plugins]
  rsync_cmd << "#{ssh_target}:#{MITAMAE_DIR}/"
  log.info("Syncing cookbooks/plugins")
  run_cmd(*rsync_cmd)

  log.info("Rendering base.yaml and default runtime.yaml")
  base_yaml_cmd = <<~CMD
    test -d #{MITAMAE_DIR}/data || mkdir -p #{MITAMAE_DIR}/data
    test -f #{RUNTIME_YAML} || { echo '--- {}'; echo; } > #{RUNTIME_YAML}#{'    '}
    cat > #{BASE_YAML}
  CMD
  IO.popen(["ssh", ssh_target, base_yaml_cmd], "w") do |cmd|
    cmd.write(YAML.dump(attrs))
  end
  abort "Failed to write base.yaml" unless $CHILD_STATUS.success?

  mitamae_cmd = <<~CMD.squeeze(' ')
    cd #{MITAMAE_DIR} && \
      mitamae local #{mitamae_opts} \
        -y data/base.yaml -y data/runtime.yaml \
        lib/mitamae_defines.rb #{run_list.join(' ')}
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
    host_list.each { |host| puts host }
  end

  desc "show host's merged config (usage: rake hosts:show[v1be])"
  task :show do |_t, args|
    hostname = args.extras.first or abort "Usage: rake hosts:show[hostname]"
    globals = DeployHelpers.load_config("./data/vars")
    host_config = DeployHelpers.load_config("./data/hosts/#{hostname}")
    merged = globals.merge(host_config)
    ppp(merged)
  end
end

namespace :deploy do
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
task mirb: "mitamae:mirb"
task list: "hosts:list"
task show: "hosts:show"
