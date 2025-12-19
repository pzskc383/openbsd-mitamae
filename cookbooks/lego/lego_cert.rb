directory "/var/lego/scripts"

define :lego_cert, cert: nil do
  name = params[:name]
  cert = params[:cert]

  template "/var/lego/scripts/#{name}.sh" do
    source "templates/lego.sh.erb"
    mode "0700"
    variables(cert: cert)
  end
  node[:relayd_tls_certs] << name if ::File.exist?("/etc/ssl/#{name}.crt")
  notify! "create@template[/etc/relayd.conf]"
end
