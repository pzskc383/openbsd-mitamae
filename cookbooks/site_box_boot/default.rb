node[:relayd_http_filter_snippets].append <<~SNIPPET
  match request header "Host" value "boot.my.b0x.pw" tag "box-boot"
  match request header "Host" value "b.b0x.pw" tag "box-boot"
  match request header "User-Agent" value "iPXE/*" tagged "box-boot" tag "box-boot-ipxe"
  match request header "User-Agent" value "UefiHttpBoot/*" tagged "box-boot" tag "box-boot-uefi"
  pass request tagged "box-boot-ipxe" header set "Host" value "ipxe.$HOST"
  pass request tagged "box-boot-uefi" header set "Host" value "uefi.$HOST"
  pass request tagged "box-boot"
SNIPPET

template "/etc/httpd.conf.d/box_boot.conf" do
  source "templates/box_boot.conf.erb"
  notifies :reload, 'service[httpd]'
end
node[:httpd_config_files] << "box_boot.conf"

BOOT_BOX_ROOT_FILES = %w[favicon.ico index.html robots.txt].freeze

directory "/var/www/htdocs/box_boot/root"
remote_file "/var/www/htdocs/box_boot/root/index.html" do
  source "files/index.html"
  mode '0644'
end

%w[favicon.ico robots.txt].each do |fname|
  link "/var/www/htdocs/box_boot/root/#{fname}" do
    to "/htdocs/box_boot/root/#{fname}"
  end
end

directory "/var/www/htdocs/box_boot/xyz" do
  mode "0755"
end

%w[bsd alpine fedora].each do |os|
  directory "/var/www/htdocs/box_boot/#{os}" do
    mode "0755"
  end

  BOOT_BOX_ROOT_FILES.each do |fname|
    link "/var/www/htdocs/box_boot/#{os}/#{fname}" do
      to "/htdocs/box_boot/root/#{fname}"
    end
  end
end

include_recipe "../openbsd_server/defines.rb"
newsyslog_snippet "http_site_boot" do
  content <<~EXTRA
    /var/www/logs/access.box_boot.log                644  4     *    $W0   Z "rcctl reload httpd"
    /var/www/logs/error.box_boot.log                 644  7     250  *     Z "rcctl reload httpd"
  EXTRA
end
