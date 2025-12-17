node[:relayd_tls_certs] ||= []
node[:relayd_tls_certs] << "b0x.pw"

notify!("create@template[/etc/relayd.conf]")

node[:httpd_config_files] << "box_main.conf"
remote_file "/etc/httpd.conf.d/box_main.conf" do
  source "templates/box_main.conf.erb"
  notifies :reload, 'service[httpd]'
end

directory "/var/www/htdocs/box_main"
%w[favicon.ico index.html robots.txt].each do |fname|
  remote_file "/var/www/htdocs/box_main/#{fname}" do
    source "files/#{fname}"
    mode '0644'
  end
end

directory "/var/www/htdocs/box_main/err"
remote_file "/var/www/htdocs/box_main/err/err.html" do
  source "files/err.html"
  mode "0644"
end

include_recipe "../openbsd_server/defines.rb"
newsyslog_snippet "http_site_main" do
  content <<~EXTRA
    /var/www/logs/access.box_main.log                644  4     *    $W0   Z "rcctl reload httpd"
    /var/www/logs/error.box_main.log                 644  7     250  *     Z "rcctl reload httpd"
  EXTRA
end
notify!("create@template[/etc/newsyslog.conf]")
