node[:relayd_http_filter_snippets].append <<~SNIPPET
  pass request header "Host" value "pzskc383.dp.ua"
  pass request header "Host" value "pzskc383.net"
SNIPPET

notify!("create@template[/etc/relayd.conf]")

remote_file "/etc/httpd.conf.d/main_pzskc383.conf" do
  source "templates/main_pzskc383.conf.erb"
  notifies :reload, 'service[httpd]'
end

node[:httpd_config_files] << "main_pzskc383.conf"
notify!("create@template[/etc/httpd.conf]")

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
