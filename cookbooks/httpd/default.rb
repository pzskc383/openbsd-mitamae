# HTTPD cookbook - OpenBSD's httpd web server with relayd
node.reverse_merge!({
  relayd_tls_certs: [],
  relayd_http_filter_snippets: [],
  httpd_config_files: []
})

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

template '/etc/httpd.conf' do
  source 'templates/httpd.conf.erb'
  notifies :restart, 'service[httpd]'
end

directory '/etc/relayd.conf.d'

template '/etc/relayd.conf.d/http_routing.conf' do
  source 'templates/relayd.http_routing.conf.erb'
  notifies :restart, 'service[relayd]'
end

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

service 'httpd' do
  action %i[enable start]
  only_if "httpd -n"
end

service 'relayd' do
  action %i[enable start]
  only_if "relayd -n"
end

include_recipe "../pf/defines.rb"
node[:pf_enable_relayd] = true
%w[http https].each do |port|
  pf_open "relayd/#{port}" do
    label "http"
    port port
  end
end

include_recipe "../openbsd_server/defines.rb"
newsyslog_snippet "http_default" do
  content <<~LOGS
    /var/www/logs/access.default.log                644  4     *    $W0   Z "rcctl reload httpd"
    /var/www/logs/error.default.log                 644  7     250  *     Z "rcctl reload httpd"
    /var/www/logs/access.fqdn.log                   644  4     *    $W0   Z "rcctl reload httpd"
    /var/www/logs/error.fqdn.log                    644  7     250  *     Z "rcctl reload httpd"
  LOGS
end
