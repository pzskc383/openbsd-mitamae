# HTTPD cookbook - OpenBSD's httpd web server with relayd
node.reverse_merge!({
  relayd_has_fqdn_cert: false,
  httpd_config_files: []
})

fqdn_hosts = {
  "host" => node[:fqdn],
  "v4" => node[:network_setup].v4.address,
  "v6" => node[:network_setup].v6.address
}

directory "/etc/httpd.conf.d"

remote_file '/etc/httpd.conf.d/macro.conf' do
  source 'files/httpd.macro.conf'
  notifies :restart, 'service[httpd]'
  notifies :restart, 'service[relayd]'
end
remote_file '/etc/httpd.conf.d/default.conf' do
  source 'files/httpd.default.conf'
  notifies :restart, 'service[httpd]'
end
template '/etc/httpd.conf.d/fqdn.conf' do
  source 'templates/httpd/fqdn.conf.erb'
  variables(fqdn_hosts: fqdn_hosts)
  notifies :restart, 'service[httpd]'
end

template '/etc/httpd.conf' do
  source 'templates/httpd.conf.erb'
  notifies :restart, 'service[httpd]'
end

node[:relayd_has_fqdn_cert] = File.exist? '/etc/ssl/fqdn.crt'
node[:relayd_has_tls] = node[:relayd_has_fqdn_cert] || !node[:relayd_domains].nil?

directory '/etc/relayd.conf.d'
remote_file '/etc/relayd.conf.d/http_headers.conf' do
  source 'files/relayd.http_headers.conf'
  notifies :restart, 'service[relayd]'
end
template '/etc/relayd.conf.d/http_relay.conf' do
  source 'templates/relayd/http_relay.conf.erb'
  notifies :restart, 'service[relayd]'
end
template '/etc/relayd.conf.d/tls_relay.conf' do
  source 'templates/relayd/tls_relay.conf.erb'
  notifies :restart, 'service[relayd]'
end
template '/etc/relayd.conf' do
  source 'templates/relayd.conf.erb'
  notifies :restart, 'service[relayd]'
end

directory '/var/www/errdocs' do
  mode '0755'
  owner 'root'
  group 'daemon'
end
remote_file "/var/www/errdocs/err.html" do
  source 'files/err.html'
  mode '0644'
  owner 'root'
  group 'daemon'
end

directory "/var/www/htdocs/fqdn"
fqdn_hosts.each do |type, value|
  directory "/var/www/htdocs/fqdn/#{type}"
  template "/var/www/htdocs/fqdn/#{type}/index.html" do
    source "templates/site.fqdn/hello.html.erb"
    variables(hostname: value)
    mode "0644"
    owner "root"
    group "daemon"
  end
end

service 'httpd' do
  action %i[enable start]
  only_if "httpd -n"
end

service 'relayd' do
  action %i[enable start]
  only_if "relayd -n"
end

include_recipe "../pf/defines.rb"
pf_snippet 'httpd' do
  content <<~PF
    # http and https services
    pass proto tcp to port { http https } set queue http
  PF
end
node[:pf_enable_relayd] = true
notify!("create@template[/etc/pf.conf]")

include_recipe "../openbsd_server/defines.rb"
snippet = %w[default fqdn].map do |host|
  <<~EXTRA
    /var/www/logs/access.#{host}.log                644  4     *    $W0   Z "rcctl reload httpd"
    /var/www/logs/error.#{host}.log                 644  7     250  *     Z "rcctl reload httpd"
  EXTRA
end.join
newsyslog_snippet "http_default" do
  content snippet
end
notify!("create@template[/etc/newsyslog.conf]")
