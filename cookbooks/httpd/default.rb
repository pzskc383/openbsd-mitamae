# HTTPD cookbook - OpenBSD's httpd web server with relayd
node.reverse_merge!({
  relayd_tls_certs: [],
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

directory '/etc/relayd.conf.d'
remote_file '/etc/relayd.conf.d/http_headers.conf' do
  source 'files/relayd.http_headers.conf'
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
%w[http https].each { |port| pf_open(port) }
node[:pf_enable_relayd] = true
notify!("create@template[/etc/pf.conf]")

include_recipe "../openbsd_server/defines.rb"
newsyslog_snippet "http_default" do
  content <<~LOGS
    /var/www/logs/access.default.log                644  4     *    $W0   Z "rcctl reload httpd"
    /var/www/logs/error.default.log                 644  7     250  *     Z "rcctl reload httpd"
    /var/www/logs/access.fqdn.log                   644  4     *    $W0   Z "rcctl reload httpd"
    /var/www/logs/error.fqdn.log                    644  7     250  *     Z "rcctl reload httpd"
  LOGS
end
notify!("create@template[/etc/newsyslog.conf]")
