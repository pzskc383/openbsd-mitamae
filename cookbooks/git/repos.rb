node[:git_repos] ||= []

git_root = node[:git_root]
git_default_owner = "Alex D."


node[:git_repos].each do |repo|
  name = repo[:name]
  repo_path = "#{git_root}/#{name}"

  execute "create git-repo #{name}" do
    command "git init --bare --template=#{git_root}/.template #{repo_path}"

    not_if "test -d #{repo_path}"
  end

  config_cmd = "git --git-dir=#{repo_path} config set"
  config_commands = ["set -e -u"]

  %w[cgit gitweb].each do |pk|
    %i[category description]. each do |k|
      config_commands << "#{config_cmd} #{pk}.#{k} '#{repo[k]}'" if repo[k]
    end
    config_commands << "#{config_cmd} #{pk}.owner '#{git_default_owner}'"
  end

  if repo[:hidden] then
    config_commands << "#{config_cmd} cgit.hide true"
    config_commands << "#{config_cmd} cgit.ignore true"
    config_commands << "rm -f #{repo_path}/git-daemon-export-ok"
  else
    config_commands << "touch #{repo_path}/git-daemon-export-ok"
  end

  config_commands << "chown -R git:git #{repo_path}"

  execute "set git-repo #{name} settings" do
    command config_commands.join("\n")
  end
end