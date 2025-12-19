openbsd_package "gophernicus"

include_recipe "../openbsd_server/defines.rb"
inetd_conf_lines "gophernicus" do
  lines [<<~LINE]
    gopher stream tcp nowait _gophernicus /usr/local/libexec/in.gophernicus in.gophernicus -h hole.pzskc383.dp.ua -l /var/log/gopher.log -nv -nm -nu -nx -nf
  LINE
end

remote_file '/var/gopher/index.gophermap' do
  source "files/index.gophermap"
  mode "0644"
end

include_recipe "../pf/defines.rb"
pf_open "gopher"
