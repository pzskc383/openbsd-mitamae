openbsd_package "gophernicus"

block_in_file "/etc/inetd.conf" do
  marker_start "# gopher"
  marker_end   "# end gopher"
  content <<~EOCONF
    gopher stream tcp nowait _gophernicus /usr/local/libexec/in.gophernicus in.gophernicus -h hole.pzskc383.dp.ua -l /var/log/gopher.log -nv -nm -nu -nx -nf
  EOCONF

  notifies :restart, "service[inetd]"
end
service "inetd"

remote_file '/var/gopher/index.gophermap' do
  source "files/index.gophermap"
  mode "0644"
end

include_recipe "../pf/defines.rb"
pf_open "gopher"
