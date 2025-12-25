group "_cert" do
  gid 1998
end

directory "/etc/ssl/private" do
  owner "root"
  group "_cert"
  mode "0750"
end
