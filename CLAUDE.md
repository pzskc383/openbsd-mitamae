# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a mitamae configuration for managing OpenBSD servers. Mitamae is an mruby-based configuration management tool (mini-Chef) that manages OpenBSD VPS instances for DNS, mail, and web services.

**Key servers:**
- **f0rk** (f0): Primary server (DNS, mail, certificates, web, XMPP, gopher)
- **airstrip3** (a3): Secondary server (DNS, mail)

## Common Commands

### Secrets Management
```bash
# Decrypt secrets before working
rake sops:decrypt

# Re-encrypt secrets after editing
rake sops:encrypt
```

### Deployment
```bash
# List all hosts
hocho list

# Deploy to specific host (dry-run)
hocho apply --dry-run airstrip3

# Deploy to specific host
hocho apply airstrip3
```

### Development
```bash
# Lint Ruby code
bundle exec rubocop

# Fix linting issues automatically
bundle exec rubocop -a
```

### WireGuard VPN

Configured in `cookbooks/openbsd_wireguard/` for server-to-server and client VPN connectivity.

**Configuration:**
- Interface: wg0
- Config: `data/vars/wireguard.yml`, `data/vars/wireguard-keys.sops.yml`
- Supports roaming peers, home network peers, local peers

### Prosody XMPP

Configured in `cookbooks/prosody/` for XMPP/Jabber instant messaging.

**Components:**
- Prosody XMPP server
- coturn (turnserver) - TURN server for NAT traversal
- Config: `data/vars/prosody.sops.yml`

**Note:** restund is broken on ARM64 and not currently used.

## Architecture

### Mitamae vs Chef

While mitamae looks like Chef, **it is NOT Chef**. Refer to `misc/mitamae/mrblib/mitamae/` for the actual mitamae implementation. Key differences:

- **mruby-based**: Compiled, not Ruby. Limited stdlib.
- **Resource model**: Similar to Chef but simplified. See `misc/mitamae/mrblib/mitamae/resource/base.rb` for the base resource implementation.
- **Plugin system**: Custom resources live in `plugins/` and follow the naming  pattern `{,m}itamae-plugin-resource-*/mrblib/**/*.rb`.

### Directory Structure

```
/
├── hocho.yml                      # Hocho configuration
├── Rakefile                       # SOPS encryption/decryption tasks
├── .sops.yaml                     # SOPS encryption configuration
├── bin/                           # Bundler binstubs (hocho monkeypatch)
├── data/                          # Host definitions and variables
│   ├── hosts/                     # Per-host configs (directories)
│   │   ├── airstrip3/
│   │   │   ├── default.yml        # Host properties and run_list
│   │   │   └── secrets.sops.yml   # SOPS-encrypted host secrets
│   │   └── f0rk/
│   │       ├── default.yml
│   │       └── secrets.sops.yml
│   └── vars/                      # Global variables (split by domain)
│       ├── default.yml            # Base configuration
│       ├── secrets.sops.yml       # Encrypted global secrets
│       ├── knot.yml               # DNS configuration
│       ├── mail.yml               # Mail server configuration
│       ├── prosody.sops.yml       # Encrypted Prosody XMPP secrets
│       ├── wireguard.yml          # WireGuard configuration
│       └── wireguard-keys.sops.yml # Encrypted WireGuard keys
├── cookbooks/                     # Mitamae recipes
│   ├── openbsd_server/            # Main server config (vim, network, etc)
│   ├── openbsd_admin/             # Admin tools (git, zsh, doas, tmux)
│   ├── openbsd_com0/              # Serial console configuration
│   ├── openbsd_wireguard/         # WireGuard VPN configuration
│   ├── pf/                        # Packet filter (firewall) configuration
│   ├── knot/                      # Knot DNS server
│   ├── lego/                      # Unified ACME cert management
│   ├── dickd/                     # Custom dickd service
│   ├── dovecot/                   # Dovecot IMAP server
│   ├── httpd/                     # OpenBSD httpd web server
│   ├── ldap/                      # LDAP server configuration
│   ├── smtpd/                     # OpenSMTPD mail server
│   ├── prosody/                   # Prosody XMPP server
│   ├── gopher/                    # Gopher protocol server
│   ├── site_main/                 # Main website configuration
│   ├── site_box_boot/             # iPXE/UEFI HTTP Boot hosting
│   ├── site_box_main/             # Main b0x.pw site
│   ├── site_box_post/             # Mail/postal services site
│   └── site_fqdn/                 # FQDN-based virtual hosting
├── plugins/                       # Custom mitamae plugins
│   ├── mitamae-plugin-resource-openbsd_package/
│   ├── mitamae-plugin-resource-cron/  # Git submodule
│   └── mitamae-plugin-resource-ldap_object/
├── lib/                           # Custom extensions
│   ├── mitamae_ext.rb             # Removes sudo/doas (running as root)
│   ├── mitamae_defines.rb         # Custom resource definitions
│   ├── hocho_ext.rb               # OpenBSD compatibility (sh, doas)
│   └── hocho/inventory_providers/
│       └── yaml_dir.rb            # YAML directory inventory provider
├── deploy/                        # WIP: Deploy mitamae with mitamae
│   ├── default.rb                 # Host definitions
│   ├── defines.rb                 # Custom defines (host, run_on)
│   ├── helpers.rb                 # Deployment helpers
│   └── recipes/                   # Per-host deployment recipes
├── dist/                          # Pre-compiled mitamae binaries
│   ├── mitamae-arm64-linux        # Linux ARM64
│   ├── mitamae-x86_64-linux       # Linux x86_64
│   ├── mitamae-arm64-openbsd      # OpenBSD ARM64
│   ├── mitamae-x86_64-openbsd     # OpenBSD x86_64
│   └── mitamae-x86_64-openbsd.old # Backup
└── misc/                          # Reference materials (git submodules)
    ├── mitamae/                   # Mitamae source
    ├── sorah-cnw/                 # Example configs
    └── example-ruby-*/            # Ruby infra examples
```

### Cookbook Overview

**Core Infrastructure:**
- **openbsd_server** - Base config (vim, DNS, network, sysctl) + shared defines.rb (sysctl, newsyslog_snippet, notify!)
- **openbsd_admin** - Admin tools (git, zsh, doas, SSH hardening)
- **openbsd_com0** - Serial console configuration
- **pf** - Packet filter firewall + pf_open define

**DNS & Certificates:**
- **knot** - Knot DNS with DNSSEC
- **lego** - Unified ACME cert management (lego_cert resource, cert_group.rb)

**Mail:**
- **smtpd** - OpenSMTPD with DKIM
- **dovecot** - IMAP/LMTP with sieve

**Web:**
- **httpd** - OpenBSD httpd + relayd (TLS termination)
- **site_main** - Primary website (cgit, gotwebd)
- **site_box_boot** - iPXE/UEFI HTTP Boot hosting
- **site_box_main** - Main b0x.pw site
- **site_box_post** - Mail/postal services site
- **site_fqdn** - Per-host dynamic configuration

**Communication:**
- **prosody** - XMPP/Jabber server (includes coturn.rb sub-recipe)

**Networking:**
- **openbsd_wireguard** - WireGuard VPN

**Other:**
- **ldap** - OpenLDAP directory
- **gopher** - Gopher server (geomyidae)
- **dickd** - Custom telnet daemon

### Hocho Integration

**Hocho** is a mitamae wrapper for multi-host orchestration.

Key files:
- `hocho.yml`: Defines inventory providers, property providers, and driver options
- `data/hosts/*/default.yml`: Host properties and run_list
- `data/hosts/*/secrets.sops.yml`: SOPS-encrypted host-specific secrets (SSH credentials, network config)
- `data/vars/*.yml`: Global variables split by domain (default, knot, mail, wireguard, prosody)
- `data/vars/secrets.sops.yml`: Encrypted global secrets

Custom extensions in `lib/`:
- **`mitamae_ext.rb`**: Removes sudo/doas command wrapping (since we connect as root directly)
  - Overrides `build_command` to skip user switching
  - Connects node object to backend for custom resource access
- **`mitamae_defines.rb`**: Custom resource definitions (block_in_file, lines_in_file, notify!)
- **`hocho_ext.rb`**: Patches hocho for OpenBSD compatibility (loaded via `bin/hocho:28` binstub)
  - Uses `sh` instead of `bash`
  - Customizes rsync sync (only cookbooks, lib, plugins directories)
- **`yaml_dir.rb`**: Custom inventory provider that loads hosts from YAML directory structure

Configuration flow:
1. `bin/hocho` binstub loads `hocho_ext.rb` (OpenBSD patches)
2. Hocho reads `hocho.yml` configuration
3. `hocho.yml` initializers load `mitamae_ext.rb` and `mitamae_defines.rb`
4. Loads host inventory via `yaml_dir` provider from `data/hosts/*/`
5. Applies property providers to set defaults (`sudo_required: false`, `ssh_options.user: root`)
6. Executes mitamae driver, connecting as root directly (no sudo/doas needed)

### Custom Plugins

#### openbsd_package

`plugins/mitamae-plugin-resource-openbsd_package/` provides `openbsd_package` resource:

**Resource definition** (`mrblib/resource/openbsd_package.rb`):
- Attributes: `name`, `version`, `flavor`, `branch`
- Actions: `:install`, `:remove`

**Executor** (`mrblib/resource_executor/openbsd_package.rb`):
- Parses OpenBSD package names with regex (VERSION_RE, FUZZY_RE)
- Uses `pkg_info`, `pkg_add`, `pkg_delete` commands
- Handles package versions, flavors (e.g., `no_x11`), and branches

Usage example:
```ruby
openbsd_package "vim" do
  action :install
  flavor "no_x11"
end
```

#### cron

`plugins/mitamae-plugin-resource-cron/` (git submodule from itamae-plugins):

**Attributes**: `minute`, `hour`, `day`, `month`, `weekday`, `command`, `user`, `mailto`, `path`, `shell`, `home`, `time`, `environment`

**Actions**: `:create`, `:delete`

Usage example:
```ruby
cron "backup_job" do
  hour "2"
  minute "0"
  command "/usr/local/bin/backup.sh"
end
```

### Reference Materials
- Mitamae source: `misc/mitamae/mrblib/mitamae/`
- Example configs: `misc/sorah-cnw/`

## Common Issues and Solutions

### Resource Actions and Subscriptions

When using `subscribes` with resources, you must specify the action that the **subscribing resource** should take, not the action of the watched resource.

**Incorrect:**
```ruby
template "/path/to/file" do
  subscribes :run, 'local_ruby_block[trigger]'  # ❌ templates don't have :run action
end
```

**Correct:**
```ruby
template "/path/to/file" do
  subscribes :create, 'local_ruby_block[trigger]'  # ✅ use the template's action
end
```

### SSH Configuration

In host secrets files, use `host_name` (with underscore) for net-ssh compatibility:

**Incorrect:**
```yaml
ssh_options:
  hostname: 192.0.2.1  # ❌ invalid net-ssh option
```

**Correct:**
```yaml
properties:
  addr: 192.0.2.1      # ✅ use addr in properties
ssh_options:
  host_name: 192.0.2.1 # ✅ or use host_name in ssh_options
  port: 22
```

### Running as Root

This configuration connects as root directly (`ssh_options.user: root`) and has `sudo_required: false`. The `mitamae_ext.rb` monkey patch removes all sudo/doas wrapping since it's unnecessary when already running as root.
