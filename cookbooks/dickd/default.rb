# dickd - erection serving daemon
dickd_builddir = "/tmp/dickd-build"
dickd_chroot = "/var/bothome"
dickd_bin = "#{dickd_chroot}/dick"

has_dickd = run_command("test -x #{dickd_bin}", error: false).exit_status == 0

directory dickd_chroot do
  owner "nobody"
  group "nobody"
  mode "0755"
end

git "dickd build dir" do
  repository "https://git.sr.ht/~pzskc383/erection"
  destination dickd_builddir
  not_if { has_dickd }
end

execute "compile erection" do
  command "make erection.fast &&j install -onobody -gnobody -m 0755 erection.fast #{dickd_bin}"
  cwd dickd_builddir
  not_if { has_dickd }
end

directory dickd_builddir do
  action :delete
  not_if { has_dickd }
end

include_recipe "../openbsd_server/defines.rb"
inetd_conf_lines "erection" do
  lines [
    "telnet stream tcp  nowait nobody #{dickd_bin} erection",
    "telnet stream tcp6 nowait nobody #{dickd_bin} erection"
  ]
end

pf_open "telnet" do
  label "misc"
end

service "inetd" do
  action %i[enable start]
end
