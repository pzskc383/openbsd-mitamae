directory "/var/lego/scripts"
node[:relayd_tls_certs] ||= []

define :lego_cert, cert: nil do
  name = params[:name]
  cert = params[:cert]

  template "/var/lego/scripts/#{name}.sh" do
    source "templates/lego.sh.erb"
    mode "0700"
    variables(cert: cert)
  end

  cert_path = "/etc/ssl/#{name}.crt"
  node[:relayd_tls_certs] << name if ::File.exist?(cert_path)
end
