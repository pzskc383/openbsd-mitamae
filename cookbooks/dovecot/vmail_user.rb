group "vmail" do
  gid 2000
end

execute "create vmail user" do
  command "useradd -g vmail -d /var/vmail -u 2000 -s /sbin/nologin -c 'Virtual Mail User' vmail"
  not_if "id vmail"
end

directory "/var/vmail" do
  mode "0775"
  owner "vmail"
  group "vmail"
end
