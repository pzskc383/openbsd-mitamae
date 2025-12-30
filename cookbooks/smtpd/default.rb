# OpenSMTPD mail server cookbook

node.reverse_merge!(
  mail_domains: {},
  mail_admin_aliases: %w[MAILER-DAEMON postmaster hostmaster
                         operator www security manager dumper
                         noc webmaster],
  mail_tls_cert: "/etc/ssl/fqdn.crt",
  mail_tls_key: "/etc/ssl/private/fqdn.key"
)

primary_domains = []
relay_domains = []
mail_accounts = []

node[:mail_domains].each do |domain, config|
  servers = config[:servers] || []
  next if servers.empty?

  if servers[0] == node[:hostname]
    config[:redirects] ||= []
    config[:accounts] ||= []

    primary_domains << domain

    config[:accounts].each do |acc|
      mail_accounts << {
        email: "#{acc[:username]}@#{domain}",
        password_hash: acc[:password_hash]
      }
    end
  elsif servers.include?(node[:hostname])
    relay_domains << domain
  end
end

mail_role = primary_domains.empty? ? "secondary" : "primary"

node[:mail_role] = mail_role
node[:mail_primary_domains] = primary_domains
node[:mail_relay_domains] = relay_domains

file "/etc/mail/mailname" do
  content node[:fqdn]
  mode "0664"
  notifies :restart, "service[smtpd]"
end

if mail_role == "primary"
  include_recipe "mailpasswd_group.rb"
  include_recipe "../dovecot/vmail_user.rb"

  execute "usermod -G _mailpasswd _smtpd" do
    not_if "id -nG _smtpd | grep -q _mailpasswd"
  end

  template "/etc/mail/passwd" do
    source "templates/passwd.erb"
    variables(accounts: mail_accounts)

    mode "0640"
    group "_mailpasswd"
  end
end

template "/etc/mail/vdomains" do
  source "templates/vdomains.erb"
  mode "0664"
  group "_smtpd"
  variables(domains: (primary_domains + relay_domains))
  notifies :run, "execute[makemap vdomains]"
  notifies :restart, "service[smtpd]"
end

if mail_role == "primary"
  template "/etc/mail/vusers" do
    source "templates/vusers.erb"
    mode "0660"
    group "_smtpd"
    variables(
      primary_domains: primary_domains,
      domains: node[:mail_domains],
      accounts: mail_accounts
    )
    notifies :run, "execute[makemap vusers]"
    notifies :restart, "service[smtpd]"
  end
end

lines_in_file "/etc/mail/aliases" do
  lines [{
    line: "root #{node[:root_mail_alias]}",
    regexp: %r{^root\s.*}
  }]
  notifies :run, "execute[newaliases]"
end

execute "newaliases" do
  action :nothing
  command "makemap -t aliases /etc/mail/aliases"
end

execute "makemap vdomains" do
  action :nothing
  command "makemap -t set /etc/mail/vdomains"
end

execute "makemap vusers" do
  action :nothing
  command "makemap -t aliases /etc/mail/vusers"
end

execute "makemap passwd" do
  action :nothing
  command "makemap -t set /etc/mail/passwd"
end

package "opensmtpd-filter-dkimsign"
directory "/etc/mail/dkim"

node[:mail_dkim_key] = "/etc/mail/dkim/private.ed25519.key"
execute "generate DKIM key" do
  command "openssl genpkey -algorithm ed25519 -outform PEM -out #{node[:mail_dkim_key]}"
  not_if { ::File.exist?(node[:mail_dkim_key]) }
end

dkim_dns_rr_result = run_command(<<~EOCMD, error: false)
  openssl pkey -outform DER -pubout -in #{node[:mail_dkim_key]} | \
    tail -c +13 | openssl base64
EOCMD
node[:mail_dkim_dns_rr] = "v=DKIM1;k=ed25519;p=#{dkim_dns_rr_result.stdout.chomp}"

template "/etc/mail/smtpd.conf" do
  source "templates/smtpd.conf.erb"
  mode "0640"
  variables(
    fqdn: node[:fqdn],
    mail_role: mail_role,
    primary_domains: primary_domains,
    relay_domains: relay_domains,
    tls_cert: node[:mail_tls_cert],
    tls_key: node[:mail_tls_key],
    mail_domains: node[:mail_domains]
  )

  notifies :run, "execute[restart_smtpd]"
end

service "smtpd" do
  action %i[enable start]
  only_if "smtpd -n"
end

execute "restart_smtpd" do
  action :nothing

  command "rcctl restart smtpd"
  only_if "smtpd -n"
end

include_recipe "../pf/defines.rb"
pf_open "smtp" do
  label "mail-server"
end
if mail_role == 'primary'
  pf_open "submission" do
    label "mail-server"
  end
end
