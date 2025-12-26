openbsd_package "dovecot"
openbsd_package "dovecot-pigeonhole"

include_recipe "../smtpd/mailpasswd_group.rb"

execute "usermod -G _mailpasswd _dovecot" do
  not_if "id -nG _dovecot | grep -qF _mailpasswd"
end

include_recipe "vmail_user.rb"

execute "usermod -G _dovecot vmail" do
  not_if "id -nG vmail |grep -qF _dovecot"
end

lines_in_file "/etc/dovecot/dovecot.conf" do
  lines [
    "protocols = imap lmtp",
    "listen = #{node[:network_setup].v4.address},#{node[:network_setup].v6.address}",
    "login_greeting = IMAP ready",
    "submission_host = 127.0.0.1:587",
    "mail_debug = yes"
  ]
end

execute "generate_dovecot_dhparam" do
  command "openssl dhparam -outform PEM -out /etc/ssl/dh-2048.pem 2048"
  not_if { ::File.exist?("/etc/ssl/dh-2048.pem") }
end

ssl_config_block = <<~SSL_BLOCK

  # DOVECOTSSL
  local_name #{node[:fqdn]} {
    ssl_cert = </etc/ssl/fqdn.crt
    ssl_key = </etc/ssl/private/fqdn.key
  }
  # /DOVECOTSSL
SSL_BLOCK
ssl_config_block = <<~SSL_BLOCK

  # DOVECOTSSL
  ssl_cert = </etc/ssl/fqdn.crt
  ssl_key = </etc/ssl/private/fqdn.key
  # /DOVECOTSSL
SSL_BLOCK

file "/etc/dovecot/conf.d/10-ssl.conf" do
  action :edit

  block do |data|
    data.gsub!(%r{^.*(ssl_key|ssl_cert)\s=\s(.*)$}, '# \1')

    data.gsub!(%r{^.*ssl\s=\s(.*)$}, 'ssl = yes')
    data.gsub!(%r{^.*ssl_dh\s=\s(.*)$}, 'ssl_dh = </etc/ssl/dh-2048.pem')

    data.gsub!(%r{# DOVECOTSSL\n.*\n# /DOVECOTSSL\n}m, '')
    data.gsub!(%r{\n\Z}m, ssl_config_block)
  end

  notifies :restart, "service[dovecot]"
end

lines_in_file "/etc/dovecot/conf.d/10-mail.conf" do
  lines [
    "mail_home = /var/vmail/%d/%n",
    {
      line: "mail_location = maildir:~/mail:LAYOUT=Maildir++",
      regex: %r{^.*mail_location.*$}
    },
    "mail_uid = vmail",
    "mail_gid = vmail",
    "mmap_disable = yes",
    "mail_plugin_dir = /usr/local/lib/dovecot",
    "mail_plugins = $mail_plugins acl quota"
  ]

  notifies :restart, "service[dovecot]"
end

remote_file "/etc/dovecot/conf.d/auth-passwdfile.conf.ext" do
  source "files/auth-passwdfile.conf.ext"
  mode "0644"
  owner "root"
  group "wheel"

  notifies :restart, "service[dovecot]"
end

lines_in_file "/etc/dovecot/conf.d/10-auth.conf" do
  lines [
    {
      regexp: %r{^!include auth-system\.conf\.ext},
      line: "#!include auth-system.conf.ext",
      append: false
    },
    {
      regexp: %r{.*#?!include auth-passwdfile\.conf\.ext},
      line: "!include auth-passwdfile.conf.ext"
    }
  ]

  notifies :restart, "service[dovecot]"
end

auth_userdb_block = <<-AUTH_USERDB_BLOCK

  unix_listener auth-userdb {
    mode = 0666
    user = vmail
    group = vmail
  }
AUTH_USERDB_BLOCK

file "/etc/dovecot/conf.d/10-master.conf" do
  action :edit
  block do |data|
    # 'service lmtp' section - add executable config
    data.gsub!(%r/service lmtp {\n.+?\n}\n/m) do |match|
      match.gsub!(%r{\s*executable =.*$}, '')
      match.gsub!(%r[\n}]m, "\n  executable = lmtp -L\n}")
    end

    # 'service auth' section - add unix_listener auth-userdb config
    # append extra_groups = _mailpasswd
    data.gsub!(%r/service auth {\n.+?\n}\n/m) do |match|
      match.gsub!(%r/\s*unix_listener auth-userdb {\n.+?\n\s+}\n/m, auth_userdb_block)

      match.gsub!(%r{\s*#?extra_groups =.*$}, '')
      match.gsub!(%r/\n}/m, "\n  extra_groups = _mailpasswd\n}")
    end

    # 'service auth-worker' section - set user = $default_internal_user
    data.gsub!(%r/service auth-worker {\n.+?\n}\n/m) do |match|
      match.gsub!(%r{\s*#?user =.*$}, '')
      match.gsub!(%r[\n}]m, "\n  user = $default_internal_user\n}")
    end
  end

  notifies :restart, "service[dovecot]"
end

file "/etc/dovecot/conf.d/20-lmtp.conf" do
  action :edit
  block do |data|
    data.gsub!(%r/protocol lmtp\s*\{.+?\n\}\n/m) do |match|
      match.gsub!(%r{\s*#?mail_plugins =.*$}, '')
      match.gsub!(%r{\s*#?info_log_path =.*$}, '')
      match.gsub!(%r{\s*#?log_path =.*$}, '')
      match.gsub!(%r{\s*#?syslog_facility =.*$}, '')

      match.gsub!(%r[\n}]m, "\n  mail_plugins = $mail_plugins sieve\n}")
      match.gsub!(%r[\n}]m, "\n  info_log_path =\n}")
      match.gsub!(%r[\n}]m, "\n  log_path =\n}")
      match.gsub!(%r[\n}]m, "\n  syslog_facility = mail\n}")
    end
  end

  notifies :restart, "service[dovecot]"
end

file "/etc/dovecot/conf.d/20-imap.conf" do
  action :edit
  block do |data|
    data.gsub!(%r/protocol imap\s*\{.+?\n\}\n/m) do |match|
      match.gsub!(%r{^\s*#?mail_plugins\s+=.*$}, "  mail_plugins = $mail_plugins imap_acl imap_quota mail_log notify")
    end
  end
end

block_in_file "/etc/dovecot/conf.d/10-metrics.conf" do
  content <<~STATS
    service stats {
      client_limit = 100
      unix_listener stats-writer {
        user = vmail
      }
    }
  STATS

  notifies :restart, "service[dovecot]"
end

service "dovecot" do
  action %i[enable start]
  only_if "doveconf"
end

include_recipe "../pf/defines.rb"
pf_open "imap" do
  label "mail-user"
end
pf_open "sieve" do
  label "mail-user"
end
