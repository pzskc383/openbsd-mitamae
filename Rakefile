require "bundler/setup"
require "hocho"

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:cop) do |task|
  task.options << '--display-cop-names'
end

desc "Set up working environment (cron plugin + dist binaries)"
task :prepare do
  sh "git submodule update --init plugins/mitamae-plugin-resource-cron"
  sh "git worktree add misc/dist dist" unless Dir.exist?("misc/dist")
end

namespace :prepare do
  desc "Set up reference material (notes, mitamae source, examples)"
  task :extras do
    sh "git worktree add misc/notes notes" unless Dir.exist?("misc/notes")
    sh "git worktree add misc/mitamae mitamae-src" unless Dir.exist?("misc/mitamae")
    sh "git submodule update --init misc/examples/example-ruby-infra misc/examples/example-ruby-git misc/examples/sorah-cnw"
  end
end

SOPS_FILES = [*Dir["./data/**/*.sops.yml"]].freeze

namespace :sops do
  desc "Decrypt secrets using SOPS"
  task :decrypt do
    SOPS_FILES.each do |file|
      cmd = "sops --decrypt -i #{file}"
      puts "Decrypting #{file}"
      system(cmd) || puts("Failed to decrypt #{file}")
    end
  end

  desc "Encrypt secrets using SOPS"
  task :encrypt do
    SOPS_FILES.each do |file|
      cmd = "sops --encrypt -i #{file}"
      puts "Encrypting #{file}"
      system(cmd) || puts("Failed to encrypt #{file}")
    end
  end
end
