node.reverse_merge!({
  git_root: "/var/www/repos",
  git_authorized_keys: []
})

git_root = node[:git_root]
git_template = "#{git_root}/.template"
git_shell_cmds = "#{git_root}/git-shell-commands"

package "git"
group "git" do
  gid 1997
end

execute "create git user" do
  command "useradd -g _gitdaemon -d #{git_root} -u 1997 -s /usr/local/bin/git-shell -c 'Git hosting user' git"
  not_if "id git"
end

directory git_root do
  owner "git"
  group "_gitdaemon"
  mode "0755"
end

file "#{git_root}/.authorized_keys" do
  content node[:git_authorized_keys].join("\n")
  mode "0600"
  owner "git"
  group "git"
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

service "gitdaemon" do
  action :enable
end

execute "set gitdaemon flags" do
  command <<~CMD
    rcctl set gitdaemon flags --verbose --syslog --informative-errors \
      --base-path=/var/www/repos /var/www/repos
  CMD
  notifies :restart, "service[gitdaemon]"
end

execute "set gitdaemon user" do
  command <<~CMD
    rcctl set gitdaemon user git
  CMD
  notifies :restart, "service[gitdaemon]"
end

file "/etc/ssh/sshd.conf.d/git" do
  content <<~SSHD_CONFIG
    Match User git LocalPort 22
      AllowAgentForwarding no
      AllowTcpForwarding no
      X11Forwarding no
      PermitTTY no
      AuthorizedKeysFile .authorized_keys
  SSHD_CONFIG

  notifies :reload, "service[sshd]"
end

include_recipe "../pf/defines.rb"
pf_open "git" do
  label "git"
  port 9418
end
