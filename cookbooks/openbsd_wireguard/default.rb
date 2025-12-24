roaming_peers = {}
net_peers = {}
me = nil
node[:wg_net][:peers].each do |peer_name, peer|
  if peer_name == node[:hostname]
    me = peer
  elsif node[:hosts][peer_name]
    net_peers[peer_name] = peer.dup.merge!({ endpoint: {
      host: node[:hosts][peer_name][:v4],
      port: node[:wg_net][:incoming_port]
    } })
  elsif peer[:endpoint]
    net_peers[peer_name] = peer
  else
    roaming_peers[peer_name] = peer
  end
end

template "/etc/hostname.wg0" do
  source "templates/hostname.wg0.erb"
  mode "0640"
  variables(
    me: me,
    roaming_peers: roaming_peers,
    net_peers: net_peers
  )
  notifies :run, "execute[netstart wg0]"
end

execute "netstart wg0" do
  action :nothing
  command "sh -x /etc/netstart wg0"
  only_if { ::File.exist? "/etc/hostname.wg0" }
end
