# uacme stores certs in:
#   /etc/ssl/uacme/<domain>/cert.pem
#   /etc/ssl/uacme/private/<domain>/key.pem
#
# We copy to /etc/ssl/<name>.crt and /etc/ssl/private/<name>.key

node[:relayd_tls_certs] ||= []

define :uacme_cert, cert: nil do
  name = params[:name]
  cert = params[:cert]

  cert_path = "/etc/ssl/#{name}.crt"

  # create per-cert issue script
  template "/etc/ssl/uacme/issue-#{name}.sh" do
    source "templates/issue.sh.erb"
    mode "0700"
    variables(cert: cert, name: name)
  end

  # register existing cert for relayd
  node[:relayd_tls_certs] << name if ::File.exist?(cert_path)
end
