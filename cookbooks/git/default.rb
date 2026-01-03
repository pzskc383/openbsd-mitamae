node.reverse_merge!({
  git_root: "/var/www/repos",
})

git_root = node[:git_root]
git_template = "#{git_root}/.template"
git_shell_cmds = "#{git_root}/git-shell-commands"

package "git"

execute "create git user" do
  command ""
  command <<~USERADD_CMD
    useradd -G _ssh_public \
      -d #{git_root} -u 1997 \
      -s /bin/rksh \
      -c 'Git hosting user' \
      git
  USERADD_CMD
  not_if "id git"
end

directory git_root do
  owner "git"
  group "git"
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
    group "git"
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
    group "git"
  end
end

include_recipe "acl.rb"
include_recipe "cgit.rb"
include_recipe "repos.rb"
# include_recipe "gitdaemon.rb"
# include_recipe "gotweb.rb"
