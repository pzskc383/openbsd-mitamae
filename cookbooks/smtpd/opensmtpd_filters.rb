package "libopensmtpd"

package "opensmtpd-filter-dkimsign"
directory "/etc/mail/dkim"

has_filter_auth = run_command("test -f /usr/local/libexec/smtpd/filter-auth", error: false).exit_status == 0
filter_auth_build_dir = "/tmp/smtpd-filter-auth-buid"

git filter_auth_build_dir do
  not_if { has_filter_auth }
  repository "https://github.com/catap/opensmtpd-filter-auth.git"
  depth 1
end

execute "build and install opensmtpd-filter-auth" do
  not_if { has_filter_auth }
  command <<~BUILD
    cd #{filter_auth_build_dir} && \
      make && \
      make install
  BUILD
end

directory filter_auth_build_dir do
  not_if { has_filter_auth }
  action :delete
end

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
