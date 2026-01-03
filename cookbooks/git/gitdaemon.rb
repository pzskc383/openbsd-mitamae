service "gitdaemon" do
  action :enable
end

execute "set gitdaemon flags" do
  command <<~CMD
    rcctl set gitdaemon flags --verbose --syslog --informative-errors \
      --base-path=#{git_root} #{git_root}
  CMD
  notifies :restart, "service[gitdaemon]"
end

execute "set gitdaemon user" do
  command <<~CMD
    rcctl set gitdaemon user git
  CMD
  notifies :restart, "service[gitdaemon]"
end

include_recipe "../pf/defines.rb"
pf_open "git" do
  label "git"
  port 9418
end
