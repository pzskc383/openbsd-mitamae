node.reverse_merge!(
  prosody_turn_secret: "",
  prosody_admin_jid: "",
  prosody_admin_password: "",
)

include_recipe "coturn.rb"

package "prosody"

execute "add _prosody to _cert group" do
  command "usermod -G _cert _prosody"
  not_if "groups _prosody |grep -qF _cert"
end

service "prosody" do
  action :enable
  only_if "prosodyctl check"
end

template "/etc/prosody/prosody.cfg.lua" do
  source "templates/prosody.cfg.lua.erb"
  notifies :restart, "service[prosody]"
  owner "_prosody"
  group "_prosody"
end

openbsd_package "mercurial"

PROSODY_COMMUNITY_MODULES_DIR = "/var/prosody/community-modules".freeze
directory PROSODY_COMMUNITY_MODULES_DIR

execute "clone prosody community modules" do
  command "hg clone https://hg.prosody.im/prosody-modules/ #{PROSODY_COMMUNITY_MODULES_DIR}"
  not_if "test -d #{PROSODY_COMMUNITY_MODULES_DIR}/.hg"
end

execute "pull prosody community modules" do
  command "hg pull --update"
  cwd PROSODY_COMMUNITY_MODULES_DIR
  only_if "test -d #{PROSODY_COMMUNITY_MODULES_DIR}/.hg"
end

execute "setup prosody admin" do
  admin_jid = node[:prosody_admin_jid]
  admin_jid_username, admin_jid_domain = admin_jid.split(%r{@})

  shellscript = <<~COMMAND
    if echo 'user:list("#{admin_jid_domain}","#{admin_jid_username}")' |\
      prosodyctl shell 2>/dev/null |grep -qF "#{admin_jid}";
    then
      { echo "#{node[:prosody_admin_password]}"; echo "#{node[:prosody_admin_password]}"; } |\
        prosodyctl passwd "#{admin_jid}"
    else
      { echo "#{node[:prosody_admin_password]}"; echo "#{node[:prosody_admin_password]}"; } |\
        prosodyctl adduser "#{admin_jid}"
    fi
  COMMAND

  command shellscript
end

include_recipe "../pf/defines.rb"
%w[xmpp-client xmpp-server].each do |port|
  pf_open port do
    port port
    proto "tcp"
    label "xmpp"
  end
end