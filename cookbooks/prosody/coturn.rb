include_recipe "../pf/defines.rb"

package "turnserver"
service "turnserver" do
  action :enable
end

execute "add _turnserver to _cert group" do
  command "usermod -G _cert _turnserver"
  not_if "groups _turnserver |grep -qF _cert"
end

template "/etc/turnserver.conf" do
  source "templates/turnserver.conf.erb"
  group "_turnserver"
  mode "0640"
  notifies :restart, "service[turnserver]"
end

ports = [3478, 3479, 5349, 5350]
protos = %w[tcp udp]
ports.each do |port|
  protos.each do |proto|
    pf_open "#{port}/#{proto}" do
      port port
      proto proto
      label "turn"
    end
  end
end

pf_open "turn/map" do
  port "63478:63878"
  proto "udp"
  label "turn"
end
