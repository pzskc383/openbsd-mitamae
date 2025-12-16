node[:relayd_tls_certs] ||= []
# node[:relayd_tls_certs] << "pzskc383.net"
node[:relayd_tls_certs] << "pzskc383.dp.ua"
node[:relayd_tls_certs]

notify!("create@template[/etc/relayd.conf]")

remote_file "/etc/httpd.conf.d/main_pzskc383.conf" do
  source "templates/main_pzskc383.conf.erb"
  notifies :reload, 'service[httpd]'
end

node[:httpd_config_files] << "main_pzskc383.conf"
notify!("create@template[/etc/httpd.conf]")

package "cgit"
service("slowcgi") { action %i[enable start] }

%w[cgitrc cgit-head.inc.html].each do |fn|
  remote_file "/var/www/conf/#{fn}" do
    source "files/cgit/#{fn}"
    mode '0444'
    owner 'www'
    group 'www'
  end
end

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

directory "/var/www/htdocs/pzskc383"

%w[bg.png splash.png index.html robots.txt favicon.ico].each do |fname|
  remote_file "/var/www/htdocs/pzskc383/#{fname}" do
    source "files/site/#{fname}"
    mode '0644'
    owner 'root'
    group 'daemon'
  end
end

include_recipe "../openbsd_server/defines.rb"
snippet = %w[main cgit main-plain git-dumb].map do |host|
  <<~EXTRA
    /var/www/logs/access.#{host}.log                644  4     *    $W0   Z "rcctl reload httpd"
    /var/www/logs/error.#{host}.log                 644  7     250  *     Z "rcctl reload httpd"
  EXTRA
end.join
newsyslog_snippet "http_site_main" do
  content snippet
end
notify!("create@template[/etc/newsyslog.conf]")
