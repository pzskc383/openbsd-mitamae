node.reverse_merge!({
  git_root: "/var/www/repos"
})

git_root = node[:git_root]
git_template = "#{git_root}/.template"
git_shell_cmds = "#{git_root}/git-shell-commands"

group "git" do
  gid 1997
end

execute "create vmail user" do
  command "useradd -g git -G _gitdaemon -d #{git_root} -u 2000 -s /usr/local/bin/git-shell -c 'Git hosting user' vmail"
  not_if "id vmail"
end

directory git_root do
  owner "git"
  group "_gitdaemon"
  mode "0755"
end

execute "create repo template" do
  command "git init --bare #{git_template}"
  not_if "test -d #{git_template}"
end

%w[post-receive post-update].each do |hook|
  remote_file "#{git_template}/hooks/#{hook}" do
    source "files/git-hooks/#{hook}"
    mode "0755"
    owner "git"
    group "_gitdaemon"
  end
end

directory git_shell_cmds do
  owner "git"
  group "_gitdaemon"
  mode "0755"
end

%w[help create-repo destroy-repo list-repos].each do |cmd|
  remote_file "#{git_shell_cmds}/#{cmd}" do
    source "files/git-shell/#{cmd}"
    mode "0750"
    owner "git"
    group "_gitdaemon"
  end
end

include_recipe "../openbsd_server/defines.rb"
inetd_conf_lines "gitdaemon" do
  lines ["git stream tcp nowait nobody /usr/bin/git git daemon --inetd --verbose #{git_root}"]
end

include_recipe "../pf/defines.rb"
pf_open "git" do
  label "git"
  port 9418
end
