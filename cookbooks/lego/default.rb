node.reverse_merge!(
  lego_certs: []
)

openbsd_package "lego"

directory "/var/lego" do
  mode "0750"
end
directory "/var/lego/hooks"
directory "/var/lego/scripts"

%w[hook hook_fqdn].each do |hookfile|
  remote_file "/var/lego/hooks/#{hookfile}.sh" do
    source "files/#{hookfile}.sh"
    mode "0755"
  end
end

node[:lego_certs].prepend({
  name: 'fqdn',
  admin_email: 'maniac@pzskc383.dp.ua',
  domains: [node[:fqdn]],
  validation_method: '--http --http.webroot /var/www/htdocs/fqdn/host',
  shell_hook: 'hook_fqdn'
})

local_ruby_block "add fqdn cert to relayd" do
  block do
    node[:relayd_tls_certs] << "fqdn" if ::File.exist?("/etc/ssl/fqdn.crt")
  end

  notifies :create, "template[/etc/relayd.conf]"
end

node[:lego_certs].each do |cert|
  template "/var/lego/scripts/#{cert[:name]}.sh" do
    source "templates/lego.sh.erb"
    mode "0750"
    variables(cert: cert)
  end
end

remote_file "/var/lego/lego.sh" do
  source "files/run_all.sh"
  mode "0755"
end

template "/var/lego/distfile" do
  source "templates/distfile.erb"
  mode "0644"
end

cron "lego certificate renewal" do
  hour '~'
  minute '~'
  day '~'
  command "/var/lego/lego.sh renew"
end
