package "cgit"

service("slowcgi") { action %i[enable start] }

# http_backend_build_dir = "/usr/ports/mystuff"
# git "http backend build dir" do
#   repository "https://git.sr.ht/~pzskc383/openbsd-ports"
#   destination http_backend_build_dir
# end

# execute "build git http backend" do
#   cwd "#{http_backend_build_dir}/devel/git-http-backend-static"
#   command "make install clean FETCH_PACKAGES="
# end

%w[cgitrc cgit-head.inc.html].each do |fn|
  remote_file "/var/www/conf/#{fn}" do
    source "files/cgit/#{fn}"
    mode '0444'
    owner 'www'
    group 'www'
  end
end
