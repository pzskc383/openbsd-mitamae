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
