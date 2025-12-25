node[:relayd_http_filter_snippets].append <<~SNIPPET
  pass request header "Host" value "post.b0x.pw"
  pass request header "Host" value "p.b0x.pw"
  pass request header "Host" value "my.post.b0x.pw"
  pass request header "Host" value "mail.b0x.pw"
  pass request header "Host" value "my.mail.b0x.pw"
SNIPPET

template "/etc/httpd.conf.d/box_post.conf" do
  source "templates/box_post.conf.erb"
  notifies :reload, 'service[httpd]'
end
node[:httpd_config_files] << "box_post.conf"

directory "/var/www/htdocs/box_post"
remote_file "/var/www/htdocs/box_post/index.html" do
  source "files/index.html"
  mode '0644'
end
%w[favicon.ico robots.txt].each do |fname|
  link "/var/www/htdocs/box_post/#{fname}" do
    to "/htdocs/box_main/#{fname}"
  end
end

include_recipe "../openbsd_server/defines.rb"
newsyslog_snippet "http_site_post" do
  content <<~EXTRA
    /var/www/logs/access.box_post.log                644  4     *    $W0   Z "rcctl reload httpd"
    /var/www/logs/error.box_post.log                 644  7     250  *     Z "rcctl reload httpd"
  EXTRA
end
