directory "/var/www/htdocs/mail"

node[:relayd_http_filter_snippets] ||= []
node[:httpd_config_files] ||= []

node[:mail_domains].each_key do |domain|
  domain_nodots = domain.gsub('.', '_')
  domain_http_root = "/var/www/htdocs/mail/#{domain_nodots}"

  smtp_host = "smtp.#{domain}"
  imap_host = "imap.#{domain}"
  mx_list = %w[the.main.b0x.pw the.far.b0x.pw]

  node[:relayd_http_filter_snippets].append <<~SNIPPET
    pass request header "Host" value "mta-sts.#{domain}"
    pass request header "Host" value "autoconfig.#{domain}"
    pass request header "Host" value "autodiscover.#{domain}"
  SNIPPET

  template "/etc/httpd.conf.d/email_#{domain_nodots}.conf" do
    source "templates/http/email_httpd_config.erb"
    variables(
      domain: domain,
      domain_nodots: domain_nodots
    )
  end
  node[:httpd_config_files] << "email_#{domain_nodots}.conf"

  # mta-sts: https://datatracker.ietf.org/doc/html/rfc8461.html
  directory "#{domain_http_root}/mta-sts"
  template "#{domain_http_root}/mta-sts/mta-sts.txt" do
    source "templates/http/mta-sts.txt.erb"
    variables(mx: mx_list)
  end

  # thunderbird autoconfig: https://wiki.mozilla.org/Thunderbird:Autoconfiguration:ConfigFileFormat
  directory "#{domain_http_root}/mozilla_autoconf"
  template "#{domain_http_root}/mozilla_autoconf/config-v1.1.xml" do
    source "templates/http/config-v1.1.xml.erb"
    variables(
      domain: domain,
      smtp_host: smtp_host,
      imap_host: imap_host
    )
  end

  # outlook autoconfig: https://learn.microsoft.com/en-us/exchange/client-developer/web-service-reference/type-pox
  directory "#{domain_http_root}/outlook_autoconf"
  template "#{domain_http_root}/outlook_autoconf/autodiscover.xml" do
    source "templates/http/autodiscover.xml.erb"
    variables(
      domain: domain,
      smtp_host: smtp_host,
      imap_host: imap_host
    )
  end
end
