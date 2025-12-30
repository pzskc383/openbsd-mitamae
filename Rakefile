require "bundler/setup"
require "pry"
require "hocho/config"
require "hocho/inventory"
require "hocho/runner"

require_relative "lib/hocho_ext"
require_relative "lib/hocho/inventory_providers/yaml_dir"

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:cop) do |task|
  task.options << '--display-cop-names'
end

def hocho_config
  Hocho::Config.load(ENV['HOCHO_CONFIG'] || './hocho.yml')
end

def hocho_inventory
  config = hocho_config
  Hocho::Inventory.new(config.inventory_providers, config.property_providers)
end

def hocho_hosts(extras = [])
  inventory = hocho_inventory
  if extras.empty?
    inventory.hosts
  else
    extras.map { |name| inventory.filter(name: name).first }
  end
end

def hocho_run(host, dry_run: false)
  config = hocho_config
  Hocho::Runner.new(
    host,
    driver: host.preferred_driver,
    base_dir: config.base_dir,
    initializers: config[:initializers] || [],
    driver_options: config[:driver_options][host.preferred_driver] || {}
  ).run(dry_run: dry_run)
end

def git_submodule_reinit(path)
  # sh "rm -rf #{path}"
  sh "git submodule update --init --remote #{path}"
end

namespace :prepare do
  desc "set up working environment (cron plugin + dist binaries + project notes)"
  task :deps do
    git_submodule_reinit "plugins/mitamae-plugin-resource-cron"
    sh "git worktree add misc/dist dist" unless Dir.exist?("misc/dist")
    sh "git worktree add misc/notes notes" unless Dir.exist?("misc/notes")
  end

  desc "set up example repos"
  task :examples do
    %w[example-ruby-infra example-ruby-git sorah-cnw].each do |name|
      path = "misc/examples/#{name}"
      git_submodule_reinit path
    end
  end

  desc "set up and compile mitamae sources"
  task :mitamae do
    git_submodule_reinit "misc/mitamae"
    sh "cd misc/mitamae && rake compile && git checkout ."
  end

  desc "everything"
  task all: ["prepare:deps", "prepare:examples", "prepare:mitamae"]
end

namespace :hocho do
  desc "pry-inspect configuration"
  task :debug do
    config = hocho_config
    inventory = hocho_inventory
    binding.pry # rubocop:disable Lint/Debugger
  end

  desc "list defined hosts"
  task :list do
    hocho_inventory.hosts.each do |host|
      puts host.name
    end
  end

  desc "run dry-run"
  task :dry_run do |_t, args|
    hosts = hocho_hosts(args.extras)

    hosts.each do |host|
      hocho_run(host, dry_run: true)
    end
  end

  desc "run deploy"
  task :deploy do |_t, args|
    hosts = hocho_hosts(args.extras)

    hosts.each do |host|
      hocho_run(host)
    end
  end
end

task prepare: "prepare:deps"
task apply: "hocho:deploy"

task default: "hocho:dry_run"
