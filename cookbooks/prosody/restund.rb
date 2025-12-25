include_recipe "../pf/defines.rb"

package "restund"
template "/etc/restund.conf" do
  source "templates/restund.conf.erb"
end

service "restund" do
  action %i[enable start]
end

pf_open "turn/udp" do
  port 3478
  proto "udp"
end
pf_open "turn/tcp" do
  port 3478
  proto "tcp"
end
