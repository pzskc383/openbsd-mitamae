openbsd_package "dovecot"
openbsd_package "dovecot-pigeonhole"
openbsd_package "bogofilter" do
  flavor "sqlite3"
end

include_recipe "../smtpd/mailpasswd_group.rb"

execute "usermod -G _mailpasswd _dovecot" do
  not_if "id -nG _dovecot | grep -qF _mailpasswd"
end

include_recipe "vmail_user.rb"

execute "usermod -G _dovecot vmail" do
  not_if "id -nG vmail |grep -qF _dovecot"
end

execute "backup original dovecot.conf" do
  command "cp -p /etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf.orig"
  not_if "test -f /etc/dovecot/dovecot.conf.orig"
end

directory "/etc/dovecot/virtual_rules"
%w[All Flagged Combined Unseen].each do |mb|
  directory "/etc/dovecot/virtual_rules/#{mb}"
  remote_file "/etc/dovecot/virtual_rules/#{mb}/dovecot-virtual" do
    source "files/virtual/#{mb}/dovecot-virtual"
  end
end

remote_file "/etc/bogofilter.cf" do
  source "files/bogofilter.cf"
  mode "0644"
end

remote_file "/etc/dovecot/dovecot-trash.conf.ext" do
  source "files/dovecot-trash.conf.ext"
  mode "0644"
end

template "/etc/dovecot/dovecot.conf" do
  source "templates/dovecot.conf.erb"
  mode "0644"
end

directory "/usr/local/share/dovecot/shell"
%w[bogofilter-classify bogofilter-train quota-warning].each do |script|
  remote_file "/usr/local/share/dovecot/shell/#{script}.sh" do
    source "files/scripts/#{script}.sh"
    mode "0755"
  end
end

%w[sieve-pipe sieve-filter].each do |dir|
  directory "/var/dovecot/#{dir}" do
    owner "_dovecot"
    group "_dovecot"
    mode "0755"
  end
end

SIEVE_SCRIPTS = {
  "sieve/before" => %w[00-bogofilter-classify 01-spamtest],
  "sieve" => %w[default],
  "imapsieve" => %w[retrain-ham train-ham train-spam],
  "sieve/global" => %w[domain-reports system-mails catchall]
}.freeze

SIEVE_SCRIPTS.each do |dir, scripts|
  basedir = "/usr/local/share/dovecot/#{dir}"

  directory basedir do
    owner "vmail"
    group "vmail"
  end

  scripts.each do |script|
    script_path = "#{basedir}/#{script}.sieve"

    execute "sievec #{script_path}" do
      action :nothing
      command "sievec #{script}.sieve && chmod 660 #{script}.* && chown :vmail #{script}.*"
      cwd basedir
      not_if "test -f #{basedir}/#{script}.svbin"
    end

    remote_file script_path do
      source "files/sieve/#{script}.sieve"
      notifies :run, "execute[sievec #{script_path}]"
      owner "vmail"
      group "vmail"
    end
  end
end
execute "generate_dovecot_dhparam" do
  command "openssl dhparam -outform PEM -out /etc/ssl/dh-2048.pem 2048"
  not_if { ::File.exist?("/etc/ssl/dh-2048.pem") }
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
