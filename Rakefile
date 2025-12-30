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

def host_list
  Pathname("./data/hosts").children.map do |path|
    path.basename.to_s
  end
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
    extras.map do |name|
      inventory.filter({ name: name }).first
    end
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

def ppp(what)
  require 'pry/color_printer'
  Pry::ColorPrinter.pp what
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
      unless Dir.exist?("misc/mitamae/mruby")
        git_submodule_reinit "misc/mitamae"
        sh "cd misc/mitamae && rake compile && git checkout ."
      end
    end
  end

  namespace :hocho do
    desc "pry-inspect configuration"
    task :debug_config do
      config = hocho_config
      inventory = hocho_inventory
      binding.pry # rubocop:disable Lint/Debugger
    end

    desc "list defined hosts"
    task :list do
      host_list.each do |host|
        puts host
      end
    end

    desc "show host's attributes"
    task :show do |_t, args|
      vars = {}
      hocho_hosts(args.extras).each do |host|
        vars[host.name] = host.properties.attributes
      end

      ppp vars
    end

    desc "show host's run_list"
  task :run_list do |_t, args|
    vars = {}
    hocho_hosts(args.extras).each do |host|
      vars[host.name] = host.run_list
    end

    ppp vars
  end

  desc "run dry-run"
  task :dry_run do |_t, args|
    hocho_hosts(args.extras).each do |host|
      hocho_run(host, dry_run: true)
    end
  end

  desc "run deploy"
  task :deploy do |_t, args|
    hocho_hosts(args.extras).each do |host|
      hocho_run(host)
    end
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
task deploy: "hocho:deploy" # rubocop:disable Rake/Desc
task dry_run: "hocho:dry_run" # rubocop:disable Rake/Desc
task list: "hocho:list" # rubocop:disable Rake/Desc
task show: "hocho:show" # rubocop:disable Rake/Desc
task run_list: "hocho:run_list" # rubocop:disable Rake/Desc
task mirb: "mitamae:mirb" # rubocop:disable Rake/Desc
