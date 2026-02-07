# i might regret thsi

%w[node libvips].each do |pkg|
  openbsd_package pkg
end

openclaw_home = "/home/openclaw"

group "openclaw" do
  gid 3000
end

user "openclaw" do
  gid "openclaw"
  home openclaw_home
  shell "/usr/local/bin/zsh"
  create_home true
end

# git "#{openclaw_home}/.oh-my-zsh" do
#   user "openclaw"
#   repository "https://github.com/ohmyzsh/ohmyzsh.git"
# end

execute "install oh-my-zsh" do
  not_if { File.exist? "#{openclaw_home}/.oh-my-zsh" }
  command <<~CMD
    git clone "https://github.com/ohmyzsh/ohmyzsh.git" "#{openclaw_home}/.oh-my-zsh"
  CMD
end

file "#{openclaw_home}/.zshrc" do
  owner "openclaw"
  group "openclaw"
  content <<~ZSHRC
    export PATH=$HOME/.local/bin:/usr/local/bin:$PATH
    export MANPATH="$HOME/.local/share/man:/usr/local/man:$MANPATH"
    export ZSH="$HOME/.oh-my-zsh"
    ZSH_THEME="gentoo"
    plugins=(git node npm)
    source $ZSH/oh-my-zsh.sh
    export EDITOR="vim"
  ZSHRC
end

file "#{openclaw_home}/.npmrc" do
  owner "openclaw"
  group "openclaw"
  content <<~NPMRC
    prefix = ${HOME}/.local
  NPMRC
end

execute "install openclaw" do
  command "su openclaw -c 'npm install -g openclaw@latest'"
  not_if { File.exist? "#{openclaw_home}/.local/bin/openclaw" }
end

pf_snippet "outgoing openclaw" do
  content "pass out $log_out on $if_public proto { tcp udp } user openclaw"
  type :out
end
