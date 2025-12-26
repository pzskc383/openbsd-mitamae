package "git"
package "zsh"
package "htop"
package "wget"
package "ncdu"

openbsd_package "rsync" do
  flavor nil
end

openbsd_package "nnn" do
  flavor nil
end

remote_file "/etc/doas.conf"
remote_file "/etc/tmux.conf"

remote_file "/root/.kshrc" do
  source "files/root.kshrc"
end

block_in_file "/root/.profile" do
  content <<~SNIPPET
    case "$SHELL" in
    *ksh)
        ENV=$HOME/.kshrc
        export ENV
        ;;
    esac
  SNIPPET
end
