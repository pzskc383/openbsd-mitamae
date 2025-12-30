# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Note:** This file lives in the `notes` branch, checked out as a worktree at `misc/notes/`. Run `rake prepare:examples` to set it up.

## Overview

This is a mitamae configuration for managing OpenBSD servers. Mitamae is an mruby-based configuration management tool (mini-Chef) that manages OpenBSD VPS instances for DNS, mail, and web services.

**Key servers:**
- **f0rk** (f0): Primary server (DNS, mail, certificates, web, XMPP, gopher)
- **airstrip3** (a3): Secondary server (DNS, mail)

## Common Commands

### Setup
```bash
# Set up working environment (cron plugin + dist binaries)
rake prepare

# Set up reference material (notes, mitamae source, examples)
rake prepare:examples
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
├── Rakefile                       # Setup tasks, SOPS, rubocop
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
├── cookbooks/                     # Mitamae recipes (see Cookbook Overview)
├── plugins/                       # Custom mitamae plugins
│   ├── mitamae-plugin-resource-openbsd_package/
│   ├── mitamae-plugin-resource-cron/  # Git submodule (external)
│   └── mitamae-plugin-resource-ldap_object/
├── lib/                           # Custom extensions
│   ├── mitamae_ext.rb             # Removes sudo/doas (running as root)
│   ├── mitamae_defines.rb         # Custom resource definitions
│   ├── hocho_ext.rb               # OpenBSD compatibility (sh, doas)
│   └── hocho/inventory_providers/
│       └── yaml_dir.rb            # YAML directory inventory provider
└── misc/                          # Optional extras (run `rake prepare` / `rake prepare:examples`)
    ├── dist/                      # [worktree: dist branch] Pre-compiled mitamae binaries
    ├── notes/                     # [worktree: notes branch] LLM docs, project notes
    ├── mitamae/                   # [submodule] Mitamae source (separate repo)
    └── examples/                  # [submodules] Example mitamae projects
        ├── example-ruby-infra/
        ├── example-ruby-git/
        └── sorah-cnw/
```

**Branches:**
- `master` - main cookbooks and config
- `dist` - mitamae binaries (worktree at misc/dist)
- `notes` - documentation, LLM guidance (worktree at misc/notes)
- `feature/deploy` - WIP deploy-mitamae-with-mitamae experiment

### Cookbook Overview

**Core Infrastructure:**
- **openbsd_server** - Base config, reasonable defaults, shared defines.rb
- **openbsd_admin** - Admin tools (vim, htop, ncdu, doas, HISTFILE)
- **pf** - Packet filter firewall, configurable logging

**DNS & Certificates:**
- **knot** - Authoritative DNS with primary/secondary AXFR
- **lego** - ACME cert management (dns-01 for wildcards)

**Mail:**
- **smtpd** - OpenSMTPD mail transport
- **dovecot** - IMAP/LMTP with sieve

**Web:**
- **httpd** - relayd (TLS) + httpd (serving)
- **site_main** - Main site + git hosting
- **site_fqdn** - Default response for FQDN/IP requests
- **site_box_*** - b0x.pw service landing pages (main, boot, post, talk)

**Communication:**
- **prosody** - XMPP server
- **openbsd_wireguard** - WireGuard VPN (internal backbone)

**Other:**
- **ldap** - OpenLDAP for unified auth (WIP)
- **gopher** - Gopher server
- **dickd** - ASCII art telnet service

### Hocho Integration

**Hocho** is a mitamae wrapper for multi-host orchestration.

Key files:
- `hocho.yml`: Defines inventory providers, property providers, and driver options
- `data/hosts/*/default.yml`: Host properties and run_list
- `data/vars/*.yml`: Global variables split by domain
- `*.sops.yml`: SOPS-encrypted secrets (can live anywhere in data/)

Custom extensions in `lib/`:
- **`mitamae_ext.rb`**: Removes sudo/doas wrapping (connects as root directly)
- **`mitamae_defines.rb`**: Custom resource definitions (block_in_file, lines_in_file, notify!)
- **`hocho_ext.rb`**: OpenBSD compatibility patches (sh instead of bash, rsync tweaks)
- **`yaml_dir.rb`**: Custom inventory provider for YAML directory structure

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
- Mitamae source: `misc/mitamae/mrblib/mitamae/` (run `rake prepare:examples` first)
- Example configs: `misc/examples/` (sorah-cnw, example-ruby-infra, example-ruby-git)

## Data Collection Pattern (notify!)

### The Problem

Multiple cookbooks need to contribute data to a shared config file:
- pf.conf (firewall rules from httpd, smtpd, prosody, etc.)
- newsyslog.conf (log rotation from various services)
- inetd.conf (superserver entries)
- relayd.conf, httpd.conf (virtual hosts)

Ideally: collect all data, render template once, reload service if changed.

### Why notify! Exists

Mitamae `define` blocks are compile-time macros, not resources. They don't have access to `notifies`:

```ruby
# This DOES NOT work:
define :pf_open do
  node[:pf_snippets] << rule
  notifies :create, "template[/etc/pf.conf]"  # ERROR: no method
end
```

The `notify!` define in `lib/mitamae_defines.rb` works around this by creating a `local_ruby_block` (which IS a resource) just to access `notifies`:

```ruby
define :notify! do
  parsed = NOTIFY_RX.match(params[:name])
  local_ruby_block "notify!#{parsed[:action]}@#{parsed[:resource]}[#{parsed[:name]}]" do
    block { true }
    notifies parsed[:action].to_sym, "#{parsed[:resource]}[#{parsed[:name]}]"
  end
end

# Usage:
define :pf_open do
  node[:pf_snippets] << rule
  notify! "create@template[/etc/pf.conf]"
end
```

### How It Breaks

The `local_ruby_block` resource is **designed to always report as changed**:

```ruby
# In mitamae: resource_executor/local_ruby_block.rb
def set_current_attributes(current, action)
  current.executed = false  # ALWAYS false
end

def set_desired_attributes(desired, action)
  desired.executed = true   # ALWAYS true
end
```

This means every `notify!` call fires its notification, even on idempotent re-runs. If 20 cookbooks call `pf_open`, you see 20 "Notifying create to template..." messages.

### Why It's (Mostly) Fine

Mitamae's template resource IS idempotent:
1. Template renders to temp file
2. Diffs against existing file (`diff -q`)
3. Only marks as `updated!` if content differs
4. Downstream notifications (service reload) only fire on actual change

So: **noisy logs, wasted CPU cycles, but correct behavior**.

Delayed notifications are deduplicated per-recipe (not globally), so the template may render multiple times per run, but the final reload only happens if content changed.

### Future Improvements

For configs that support includes (httpd, sshd), use actual `.d/` directories:
```
/etc/httpd.d/*.conf  - httpd reads directly
/etc/ssh/sshd.conf.d/*.conf - sshd reads directly
```

For configs requiring aggregation (pf, inetd), options being considered:
- Accept the current tax (noisy but correct)
- Snippets.d directories rendered into single file
- Custom resource plugin with proper idempotency

## Operational Notes

**Secrets handling:** SOPS decryption is automatic - `yaml_dir.rb` inventory provider detects `*.sops.yml` files and runs `popen3(sops -d)`.

**Server roles:**
- **f0rk** (arm64, 8GB RAM, 256GB disk) - Primary, runs everything
- **airstrip3** (x86_64, 1GB RAM, 20GB disk) - Secondary DNS/mail relay only

**Testing:** No staging environment. Use `hocho apply --dry-run`. See `misc/notes/TEST_PLAN.md` for planned libvirt-based test infrastructure (serverspec tests against isolated OpenBSD VMs).

**Known issues:**
- `local_ruby_block` always reports as "changed" by design - see "Data Collection Pattern" section above
- Notifications are deduplicated per-recipe, not globally, so templates may render multiple times per run
