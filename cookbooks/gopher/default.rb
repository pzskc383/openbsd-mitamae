openbsd_package "geomyidae"

service "geomyidae" do
  action :enable
end

geomyidae_flags = "-c -e -n -l /var/log/geomyidae.log -u _geomyidae -g _geomyidae"
execute "set geomyidae flags" do
  command "rcctl set geomyidae flags #{geomyidae_flags}"
  not_if "grep -qF 'geomyidae_flags=#{geomyidae_flags}' /etc/rc.conf.local"
  notifies :start, "service[geomyidae]"
end

remote_file '/var/gopher/index.gph' do
  source "files/index.gph"
  mode "0644"
end

include_recipe "../pf/defines.rb"
pf_open "gopher" do
  label "misc"
end
