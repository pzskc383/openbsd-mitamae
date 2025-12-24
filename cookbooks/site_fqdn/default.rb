lego_cert "fqdn" do
  cert(
    name: 'fqdn',
    admin_email: 'owner@post.b0x.pw',
    domains: [node[:fqdn]]
  )
  notifies :create, "template[/etc/relayd.conf]"
end

fqdn_hosts = {
  "host" => node[:fqdn],
  "v4" => node[:network_setup].v4.address,
  "v6" => node[:network_setup].v6.address
}

template '/etc/httpd.conf.d/fqdn.conf' do
  source 'templates/fqdn.conf.erb'
  variables(fqdn_hosts: fqdn_hosts)
  notifies :restart, 'service[httpd]'
end
node[:httpd_config_files].prepend "fqdn.conf"

directory "/var/www/htdocs/fqdn"

fqdn_hosts.each do |type, value|
  node[:relayd_http_filter_snippets].append <<~SNIPPET
    pass request header "Host" value "#{value}"
  SNIPPET

  directory "/var/www/htdocs/fqdn/#{type}"
  template "/var/www/htdocs/fqdn/#{type}/index.html" do
    source "templates/hello.html.erb"
    variables(hostname: value)
    mode "0644"
  end
end
