require "bundler/setup"
require "hocho"

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:cop) do |task|
  task.options << '--display-cop-names'
end

desc "Set up working environment (cron plugin + dist binaries + project notes)"
task :prepare do
  sh "git submodule update --init plugins/mitamae-plugin-resource-cron"
  sh "git worktree add misc/dist dist" unless Dir.exist?("misc/dist")
  sh "git worktree add misc/notes notes" unless Dir.exist?("misc/notes")
end

namespace :prepare do
  desc "Set up reference material (mitamae source, examples)"
  task :examples do
    sh "git submodule update --init misc/mitamae"
    sh "git submodule update --init misc/examples/example-ruby-infra misc/examples/example-ruby-git misc/examples/sorah-cnw"
  end
end
