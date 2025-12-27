node.reverse_merge!(inetd_conf_lines: [])

file "/etc/sysctl.conf"

execute "reload sysctl" do
  action :nothing
  command "sysctl -f /etc/sysctl.conf"
end

define :sysctl, settings: [] do
  settings = params[:settings]
  lines_in_file "/etc/sysctl.conf" do
    lines settings

    notifies :run, "execute[reload sysctl]"
  end
end

node.reverse_merge!({
  newsyslog_extra_lines: []
})

template "/etc/newsyslog.conf" do
  action :nothing
  source "templates/newsyslog.conf.erb"
  mode "0640"
end

define :newsyslog_snippet, content: nil do
  node[:newsyslog_extra_lines] << (params[:content] || params[:name])

  notify!("create@template[/etc/newsyslog.conf]")
end

service "inetd"
template "/etc/inetd.conf" do
  action :nothing
  source "templates/inetd.conf.erb"
  notifies :reload, "service[inetd]"
end

define :inetd_conf_lines, lines: [] do
  node[:inetd_conf_lines].append "# #{params[:name]}"
  params[:lines].each { |line| node[:inetd_conf_lines].append line }
  notify! "create@template[/etc/inetd.conf]"
end

directory "/etc/ssh/sshd.conf.d"
