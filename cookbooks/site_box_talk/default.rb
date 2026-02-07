node[:relayd_http_filter_snippets].append <<~SNIPPET
  pass request header "Host" value "talk.b0x.pw"
  pass request header "Host" value "chat.talk.b0x.pw"
  pass request header "Host" value "share.talk.b0x.pw"
  pass request header "Host" value "turn.talk.b0x.pw"
SNIPPET

template "/etc/httpd.conf.d/box_talk.conf" do
  source "templates/box_talk.conf.erb"
  notifies :reload, 'service[httpd]'
end
node[:httpd_config_files] << "box_talk.conf"

directory "/var/www/htdocs/box_talk"
remote_file "/var/www/htdocs/box_talk/index.html" do
  source "files/index.html"
  mode '0644'
end
%w[favicon.ico robots.txt].each do |fname|
  link "/var/www/htdocs/box_talk/#{fname}" do
    to "/htdocs/box_main/#{fname}"
  end
end

include_recipe "../openbsd_server/defines.rb"
newsyslog_snippet "http_site_talk" do
  content <<~EXTRA
    /var/www/logs/access.box_talk.log                644  4     *    $W0   Z "rcctl -q reload httpd"
    /var/www/logs/error.box_talk.log                 644  7     250  *     Z "rcctl -q reload httpd"
  EXTRA
end
