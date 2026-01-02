node.reverse_merge!(
  uacme_certs: [],
  relayd_tls_certs: []
)

include_recipe "../lego/cert_group.rb"

openbsd_package "uacme"

directory "/etc/ssl/uacme" do
  mode "0700"
end

directory "/etc/ssl/uacme/private" do
  mode "0700"
end

remote_file "/etc/ssl/uacme/hook.sh" do
  source "files/hook.sh"
  mode "0755"
end

include_recipe "uacme_cert.rb"

node[:uacme_certs].each do |cert|
  uacme_cert cert[:name] do
    cert cert
    notifies :create, "template[/etc/relayd.conf]"
  end
end

remote_file "/etc/ssl/uacme/renew.sh" do
  source "files/renew.sh"
  mode "0755"
end

cron "uacme certificate renewal" do
  hour '~'
  minute '~'
  day '~'
  command "/etc/ssl/uacme/renew.sh"
end
