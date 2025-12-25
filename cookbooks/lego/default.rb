node.reverse_merge!(
  lego_certs: [],
  relayd_tls_certs: []
)

include_recipe "cert_group.rb"

openbsd_package "lego"

directory "/var/lego" do
  mode "0750"
end
remote_file "/var/lego/hook.sh" do
  source "files/hook.sh"
  mode "0755"
end

remote_file "/var/lego/lego.sh" do
  source "files/run_all.sh"
  mode "0700"
end

template "/var/lego/distfile" do
  source "templates/distfile.erb"
  mode "0644"
end

include_recipe "lego_cert.rb"

node[:lego_certs].each do |cert|
  lego_cert cert[:name] do
    cert cert
    notifies :create, "template[/etc/relayd.conf]"
  end
end

cron "lego certificate renewal" do
  hour '~'
  minute '~'
  day '~'
  command "/var/lego/lego.sh renew"
end
