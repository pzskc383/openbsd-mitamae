node.reverse_merge!(
  prosody_turn_secret: "",
  prosody_admin_jid: "",
  prosody_accounts: []
)

include_recipe "coturn.rb"

package "prosody"

execute "add _prosody to _cert group" do
  command "usermod -G _cert _prosody"
  not_if "groups _prosody |grep -qF _cert"
end

service "prosody" do
  action :enable
end

template "/etc/prosody/prosody.cfg.lua" do
  source "templates/prosody.cfg.lua.erb"
  notifies :restart, "service[prosody]"
  owner "_prosody"
  group "_prosody"
end

# openbsd_package "mercurial"
# PROSODY_COMMUNITY_MODULES_DIR = "/var/prosody/community-modules".freeze
# directory PROSODY_COMMUNITY_MODULES_DIR
# execute "clone prosody community modules" do
#   command "hg clone https://hg.prosody.im/prosody-modules/ #{PROSODY_COMMUNITY_MODULES_DIR}"
#   not_if "test -d #{PROSODY_COMMUNITY_MODULES_DIR}/.hg"
# end
# execute "pull prosody community modules" do
#   command "hg pull --update"
#   cwd PROSODY_COMMUNITY_MODULES_DIR
#   only_if "test -d #{PROSODY_COMMUNITY_MODULES_DIR}/.hg"
# end

define :prosody_user, password: nil, role: nil do
  jid = params[:name]
  password = params[:password]
  username, domain = jid.split(%r{@})
  role = params[:role] || "prosody:registered"

  user_check = run_command(<<~CMD, error: false)
    echo "user:list('#{domain}', '#{username}')" |\
      prosodyctl shell 2>/dev/null |\
      grep -qF 'Showing 1 of '
  CMD

  execute "prosody_user #{jid}" do
    command <<~CMD
      echo "user:create('#{jid}', '#{password.shellescape}', '#{role}')" |\
        prosodyctl shell 2>/dev/null
    CMD
    not_if { user_check.exit_status == 0 }
  end
end

node[:prosody_accounts].each do |acc|
  prosody_user acc[:jid] do
    password acc[:password]
    role acc[:role]
  end
end

include_recipe "../pf/defines.rb"
%w[xmpp-client xmpp-server xmpp-bosh 5223 5970].each do |port|
  pf_open "xmpp/#{port}" do
    port port
    proto "tcp"
    label "xmpp"
  end
end

node[:relayd_http_filter_snippets].append <<~PROSODY_RELAYD_CONF
  match request header "Host" value "share.talk.b0x.pw" tag "xmpp_file_share"
  match request header "Host" value "talk.b0x.pw" tag "xmpp_domain"
  match request header "Host" value "pzskc383.dp.ua" tag "xmpp_domain"
  match request header "Host" value "pzskc383.net" tag "xmpp_domain"
  pass request tagged "xmpp_file_share" forward to <prosody_plain>
  pass request tagged "xmpp_domain" path "/http-bind" forward to <prosody_plain>
  pass request tagged "xmpp_domain" path "/xmpp-websocket" forward to <prosody_plain>
  pass request tagged "xmpp_domain" path "/.well-known/host-info" forward to <prosody_plain>
  pass request tagged "xmpp_domain" forward to <httpd_tls>
PROSODY_RELAYD_CONF
