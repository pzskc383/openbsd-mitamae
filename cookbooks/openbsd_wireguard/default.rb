peers = {
  roam: {},
  net: {},
  me: nil
}

node[:wg_net][:peers].each do |peer_name, peer|
  puts node[:hosts].inspect
  puts YAML.dump(node[:hosts])
  if peer_name == node[:hostname]
    peers[:me] = peer
  elsif node[:hosts][peer_name]
    peers[:net][peer_name] = peer.dup.merge!({
      endpoint: {
        host: node[:hosts][peer_name][:v4],
        port: node[:wg_net][:incoming_port]
      },
      netmask_v4: 32,
      netmask_v6: 128
    })
  elsif peer[:endpoint]
    peers[:net][peer_name] = peer.dup.merge!({
      netmask_v4: 24,
      netmask_v6: 112
    })
  else
    peers[:roam][peer_name] = peer
  end
end

template "/etc/hostname.wg0" do
  source "templates/hostname.wg0.erb"
  mode "0640"
  variables(
    peers: peers
  )
  notifies :run, "execute[netstart wg0]"
end

execute "netstart wg0" do
  action :nothing
  command "sh -x /etc/netstart wg0"
  only_if { ::File.exist? "/etc/hostname.wg0" }
end
