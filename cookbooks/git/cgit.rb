service("slowcgi") { action %i[enable start] }

has_git_http_backend = run_command("test -f /var/www/cgi-bin/git-http-backend", error: false).exit_status == 0

define :build_cgit do
  cgit_build_directory = "/tmp/cgit-build-dir"

  git "checkout cgit" do
    repository "https://git.sr.ht/~pzskc383/cgit"
    destination cgit_build_directory
    revision "local-hacks"
    depth 1
  end

  package "gmake"

  execute "build cgit and git-http-backend" do
    cwd cgit_build_directory

    command <<~BUILD
      set -e -u
      gmake get-git

      gmake V=1 NO_GETTEXT=1 NO_LUA=1 \
        EXTRA_GIT_TARGETS='git-upload-pack git-pack-objects git-http-backend' \
        LDFLAGS+='-static -pie -L/usr/local/lib'

      for f in http-backend upload-pack pack-objects; do
        cp "git/git-${f}" "/var/www/cgi-bin/git-${f}"
      done

      cp cgit /var/www/cgi-bin/cgit.cgi
    BUILD
  end

  directory cgit_build_directory do
    action :delete
  end

  openbsd_package "gmake" do
    action :remove
  end
end

build_cgit "build_cgit" do
  not_if { has_git_http_backend }
end

%w[cgitrc cgit-head.inc.html].each do |fn|
  remote_file "/var/www/conf/#{fn}" do
    source "files/cgit/#{fn}"
    mode '0444'
    owner 'www'
    group 'www'
  end
end
