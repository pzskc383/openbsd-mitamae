default_git_acl = {
  "*" => [{ repo: "*", access: "r" }]
}
git_root = node[:git_root]

node.reverse_merge!({
  git_authorized_keys: [],
  git_repos: [],
  git_acl_rules: default_git_acl
})

node[:git_acl_rules] ||= default_git_acl

directory "#{git_root}/.ssh" do
  owner "git"
  group "git"
  mode "0700"
end

template "#{git_root}/.ssh/authorized_keys" do
  source "templates/authorized_keys.erb"
  mode "0600"
  owner "git"
  group "git"
end

template "#{git_root}/acl.conf" do
  source "templates/acl.conf.erb"
  owner "root"
  group "_gitdaemon"
  mode "0640"
end

remote_file "/usr/local/bin/git-shell-acl" do
  source "files/git-shell-acl"
  owner "root"
  group "_gitdaemon"
  mode "0755"
end
