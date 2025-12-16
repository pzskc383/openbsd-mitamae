node[:relayd_tls_certs] ||= []
node[:relayd_tls_certs] << "b0x.pw"

notify!("create@template[/etc/relayd.conf]")

node[:httpd_config_files] << "main_box.conf"
remote_file "/etc/httpd.conf.d/main_box.conf" do
  source "templates/main_box.conf.erb"
  notifies :reload, 'service[httpd]'
end
notify!("create@template[/etc/httpd.conf]")

directory "/var/www/htdocs/box_main"
%w[favicon.ico index.html robots.txt].each do |fname|
  remote_file "/var/www/htdocs/box_main/#{fname}" do
    source "files/#{fname}"
    mode '0644'
    owner 'root'
    group 'daemon'
  end
end

include_recipe "../openbsd_server/defines.rb"
newsyslog_snippet "http_site_main" do
  content <<~EXTRA
    /var/www/logs/access.box_main.log                644  4     *    $W0   Z "rcctl reload httpd"
    /var/www/logs/error.box_main.log                 644  7     250  *     Z "rcctl reload httpd"
  EXTRA
end
notify!("create@template[/etc/newsyslog.conf]")
