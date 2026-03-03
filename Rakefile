require 'English'
require "bundler/setup"
require "pry"
require "pathname"
require "open3"
require "yaml"

require_relative "lib/deploy_helpers"

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
  puts "=> #{cmd.join(' ')}"
  system(*cmd) or abort "Command failed: #{cmd.first}"
end

def apply_host(hostname, dry_run: false, verbose: false)
  globals = DeployHelpers.load_config("./data/vars")
  host_config = DeployHelpers.load_config("./data/hosts/#{hostname}")
  base_data = globals.merge(host_config)

  run_list = base_data.dig("properties", "run_list") || []
  abort "No run_list defined for #{hostname}" if run_list.empty?

  ssh_target = base_data.dig("properties", "ssh_target") || "root@#{hostname}"

  run_cmd(%w[rsync -av --delete --exclude data cookbooks lib plugins #{ssh_target}:/etc/mitamae/])
  run_cmd("ssh", ssh_target, "mkdir -p /etc/mitamae/data")

  IO.popen(["ssh", ssh_target, "tee /etc/mitamae/node.yaml > /dev/null"], "w") do |cmd|
    cmd.write(YAML.dump(merged_data))
  end

  abort "Failed to write node.yaml" unless $CHILD_STATUS.success?

  mitamae_opts = []
  mitamae_opts << "-n" if dry_run
  mitamae_opts << "--log-level debug" if verbose

  mitamae_cmd = <<~CMD
    cd /etc/mitamae && \
      mitamae local \
        #{mitamae_opts.join(' ')} \
        -y node.yaml -y runtime.yaml \
        lib/mitamae_ext.rb lib/mitamae_defines.rb \
        #{run_list.join(' ')}
  CMD

  run_cmd("ssh", ssh_target, mitamae_cmd)
end

def git_submodule_reinit(path)
  sh "git submodule update --init --recursive --force --remote #{path}"
end

def ppp(what)
  # require 'pry/color_printer'
  # Pry::ColorPrinter.pp what
  # puts JSON.dump(what)
  puts YAML.dump(what)
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
  task :dry_run, [:verbose] do |_t, args|
    hostname = args.extras.first or abort "Usage: rake deploy:dry_run[hostname]"
    apply_host(hostname, dry_run: true, verbose: !args.verbose.nil?)
  end

  desc "apply mitamae (usage: rake deploy:apply[v1be])"
  task :apply, [:verbose] do |_t, args|
    hostname = args.extras.first or abort "Usage: rake deploy:apply[hostname]"
    apply_host(hostname, verbose: !args.verbose.nil?)
  end
end

namespace :mitamae do
  desc "run mitamae's mirb"
  task mirb: %w[prepare:mitamae] do
    sh "./misc/mitamae/mruby/bin/mirb"
  end
end

# shortcuts
task prepare: "prepare:deps" # rubocop:disable Rake/Desc
task mirb: "mitamae:mirb" # rubocop:disable Rake/Desc
task list: "hosts:list" # rubocop:disable Rake/Desc
task show: "hosts:show" # rubocop:disable Rake/Desc
