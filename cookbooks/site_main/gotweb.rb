package "gotwebd"

remote_file "/etc/gotwebd.conf" do
  source "files/gotweb/gotwebd.conf"
  notifies :restart, "service[gotwebd]"
end

remote_file "/var/www/htdocs/gotwebd/mono-gotweb.css" do
  source "files/gotweb/mono-gotweb.css"
  mode "0644"
end

link "/var/www/htdocs/gotwebd/logo.png" do
  to "/htdocs/pzskc383/images/serve.png"
end

service("gotwebd") { %i[enable start] }
