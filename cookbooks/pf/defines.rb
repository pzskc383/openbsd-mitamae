node.reverse_merge!({
  pf_snippets: []
})

# check and reload pf config
execute "reload_pf" do
  action :nothing
  command "pfctl -f /etc/pf.conf"
  only_if "pfctl -nf /etc/pf.conf"
end

template "/etc/pf.conf" do
  action :nothing
  path "/etc/pf.conf"
  mode "0600"
  notifies :run, "execute[reload_pf]"
end

define :pf_snippet, content: nil do
  node[:pf_snippets] << (params[:content] || params[:name])

  notify!("create@template[/etc/pf.conf]")
end

define :pf_open, port: nil, proto: nil, label: nil do
  port = params[:port] || params[:name]
  proto = params[:proto] || "tcp"

  rule_opts = proto == "udp" ? "keep state" : "synproxy state"
  rule_opts = "label #{params[:label]} #{rule_opts}" if params[:label]

  rule = "pass in on $if_public proto #{proto} to port #{port} #{rule_opts}"

  pf_snippet "port #{port}/#{proto}" do
    content rule
  end
end
