# PF firewall cookbook
node.reverse_merge!({
  pf_enable_relayd: false
})

include_recipe 'defines.rb'

include_recipe '../openbsd_server/defines.rb'

sysctl "pf" do
  settings %w[
    net.inet.ip.forwarding=1
    net.inet6.ip6.forwarding=1
    net.inet.icmp.maskrepl=0
    net.inet.icmp.tstamprepl=0
    net.inet.icmp.rediraccept=0
    net.inet.gre.allow=1
    net.inet.ipcomp.enable=1
    net.inet.tcp.rfc3390=1
    net.inet.ip.ifq.maxlen=8192
    net.inet.tcp.mssdflt=1460
    net.inet.ip.mtudisc=0
  ]
end

%w[hostname.pflog0].each do |f|
  file "/etc/#{f}" do
    content "up"
  end
end
directory "/etc/pf" do
  mode "0700"
end

file "/etc/pf/banned.table" do
  content ""
  not_if { ::File.exist?("/etc/pf/banned.table") }
end
