# Infrastructure Data Model

## The Problem

This repo uses mitamae to configure OpenBSD servers. Mitamae is great for "put this file here, start this service" but struggles with cross-cutting concerns where multiple entities have relationships that affect configuration.

### What We Have Now

Data is spread across `data/vars/*.yml` and `data/hosts/*/*.yml`:

```
data/
  vars/
    default.yml       # ldapd_base_dn
    knot.yml          # knot_zones (zone → primary/secondaries)
    mail.yml          # mail_domains (domain → servers, aliases, redirects)
    wireguard.yml     # wg_net peers
    secrets.sops.yml  # git_authorized_keys, ldapd_bind_pw, knot_tsig_secret, mail_domains (passwords), knot_dnssec
    prosody.sops.yml  # prosody accounts
  hosts/
    f0rk/
      default.yml     # run_list, dns_shortname, motd
      secrets.sops.yml # ssh_target, ssh_options
      lego.sops.yml   # lego_certs (cert → domains, zone, validation_method)
    airstrip3/
      default.yml     # run_list, dns_shortname, motd
      secrets.sops.yml # ssh_target, ssh_options
```

### Why Mitamae Doesn't Work

1. **No relationship traversal**: Cookbooks can't easily ask "which hosts serve this domain?" or "which certs need to notify this service?"

2. **Notification model is broken**: `local_ruby_block` always reports as changed, so `notify!` workaround fires constantly (see CLAUDE.md "Data Collection Pattern")

3. **No cross-cookbook coordination**: Each cookbook sees its own data but can't reason about the whole system

4. **Hardcoded relationships**: Things like "airstrip3 is backup MX" are hardcoded in templates instead of derived from data

### What We Actually Need

A way to:
- Define entities and their relationships
- Query relationships from any cookbook
- Derive configuration (MX records, firewall rules, cert notifications) from the model
- Have a single source of truth

## Current Entities (Observed from data/)

### Host

```yaml
# Defined in: data/hosts/*/default.yml
host:
  name: f0rk
  run_list: [...]      # which cookbooks to run
  dns_shortname: f0    # for DNS records
  role: primary|secondary  # implicit, not declared
  # From secrets.sops.yml:
  ssh_target: IP
  ssh_options: { port, user, ... }
```

**Hosts we have:** f0rk (primary), airstrip3 (secondary)

### Zone (DNS)

```yaml
# Defined in: data/vars/knot.yml
zone:
  name: pzskc383.net
  primary: f0rk        # host reference
  secondaries: [airstrip3]  # host references
```

**Zones we have:** pzskc383.net, b0x.pw

### Mail Domain

```yaml
# Defined in: data/vars/mail.yml
mail_domain:
  name: pzskc383.net
  admin_account: maniac@pzskc383.net
  catchall_account: maniac@pzskc383.net
  catchall_subdomains: true
  servers: [f0rk, airstrip3]  # host references - but what role?
  aliases: [...]       # alternative domain names
  redirects: [...]     # email redirects
```

**Mail domains we have:** pzskc383.net, pzskc383.dp.ua, post.b0x.pw

### Certificate (TLS)

```yaml
# Defined in: data/hosts/f0rk/lego.sops.yml
certificate:
  name: pzskc383.net
  admin_email: ...
  domains: [...]       # SANs
  zone: pzskc383.net   # for DNS-01 validation and TLSA records
  distributed: bool    # shared across hosts?
  validation_method: dns-01
  # Missing: which services use this cert?
```

### WireGuard Peer

```yaml
# Defined in: data/vars/wireguard.yml
wg_peer:
  name: f0rk
  address: 32          # last octet
  pubkey: ...
  endpoint: { host, port }  # optional
```

### Prosody Account (XMPP)

```yaml
# Defined in: data/vars/prosody.sops.yml
prosody_account:
  jid: user@domain
  password: ...
```

## Missing Relationships

### Certificate → Service@Host

A cert is used by services. When renewed, those services need reload.

Currently: **not modeled**. Lego hook script would need to know "cert X is used by smtpd on f0rk and airstrip3".

```
certificate "mail.pzskc383.net"
  used_by:
    - service: smtpd, host: f0rk
    - service: smtpd, host: airstrip3
    - service: dovecot, host: f0rk
```

### Mail Domain → Zone

Which zone should receive MX records for this mail domain?

Currently: **implicit**. Domain `pzskc383.net` goes in zone `pzskc383.net`. But what about `post.b0x.pw`? Goes in `b0x.pw`.

```
mail_domain "post.b0x.pw"
  zone: b0x.pw  # explicit
```

### Mail Domain → Host Role

A mail domain is served by hosts, but with different roles:

Currently: just `servers: [f0rk, airstrip3]` - no indication of primary vs backup.

```
mail_domain "pzskc383.net"
  mx_hosts:
    - host: f0rk, priority: 10      # primary
    - host: airstrip3, priority: 20  # backup
```

### Service@Host → Firewall Ports

A service on a host needs certain ports open.

Currently: **scattered in cookbooks**. Each cookbook calls `pf_open`.

```
service "smtpd", on: f0rk
  ports: [25, 587]
```

### Site → Host(s)

Can a site be deployed to multiple hosts?

Currently: **implicit in run_list**. f0rk runs site_main, site_box_*, etc.

```
site "site_main"
  hosts: [f0rk]
  # or for HA:
  hosts: [f0rk, airstrip3]
```

### Site → Domain(s) → Zone(s) → Certificate(s)

A site serves domain(s), which live in zone(s), and need cert(s).

Currently: **hardcoded in each site cookbook**.

```
site "site_box_post"
  domains: [post.b0x.pw, mail.b0x.pw]
  zone: b0x.pw
  certificate: b0x.pw-wildcard
```

## Proposed Entity Model

### Core Entities

```ruby
Host = Struct.new(
  :name,           # f0rk, airstrip3
  :role,           # :primary, :secondary
  :arch,           # arm64, x86_64
  :addrs,          # { v4: ..., v6: ... }
  :dns_shortname,  # f0, a3
  :wg_peer,        # WireGuard config
)

Zone = Struct.new(
  :name,           # pzskc383.net
  :primary,        # Host reference
  :secondaries,    # [Host] references
)

Certificate = Struct.new(
  :name,           # mail.pzskc383.net
  :domains,        # SANs
  :zone,           # Zone reference (for TLSA)
  :issuer_host,    # Host that runs lego
)

Service = Struct.new(
  :name,           # smtpd, httpd, prosody
  :host,           # Host reference
  :ports,          # [25, 587]
  :certificates,   # [Certificate] references
)

MailDomain = Struct.new(
  :name,           # pzskc383.net
  :zone,           # Zone reference
  :mx_entries,     # [{ host: Host, priority: int }]
  :accounts,       # [MailAccount]
  :aliases,        # [String]
  :dkim_key,       # DKIMKey reference
)

Site = Struct.new(
  :name,           # site_main, site_box_post
  :hosts,          # [Host] references
  :domains,        # [String]
  :certificate,    # Certificate reference
)
```

### Derived Data

From the model, we can derive:

```ruby
# All ports to open on a host
host.services.flat_map(&:ports).uniq

# MX records for a zone
zone.mail_domains.flat_map { |d| d.mx_entries.map { |e| MXRecord.new(d.name, e.priority, e.host.fqdn) } }

# Services to notify when a cert is renewed
cert.services  # => [smtpd@f0rk, smtpd@airstrip3, dovecot@f0rk]

# TLSA records for a zone
zone.certificates.map { |c| TLSARecord.new(c) }
```

## Why Not YAML?

YAML can't express relationships cleanly. You end up with:

```yaml
certificates:
  mail.pzskc383.net:
    used_by:
      - { host: f0rk, service: smtpd }
      - { host: f0rk, service: dovecot }
      - { host: airstrip3, service: smtpd }
```

This is:
- Verbose
- Error-prone (typos in host/service names)
- No validation
- Manual foreign key maintenance

## Proposed: Ruby DSL

```ruby
# infra.rb

host :f0rk do
  role :primary
  arch :arm64
  addr v4: "152.53.60.123", v6: "2a0a:..."
  dns_shortname "f0"
end

host :airstrip3 do
  role :secondary
  arch :x86_64
  addr v4: "..."
  dns_shortname "a3"
end

zone :pzskc383_net do
  name "pzskc383.net"
  primary :f0rk
  secondaries :airstrip3
end

certificate :mail_pzskc383 do
  domains "mail.pzskc383.net", "*.pzskc383.net"
  zone :pzskc383_net
  issued_on :f0rk
end

service :smtpd, on: :f0rk do
  ports 25, 587
  uses_cert :mail_pzskc383
end

service :smtpd, on: :airstrip3 do
  ports 25
  uses_cert :mail_pzskc383
  role :backup_mx
end

mail_domain :pzskc383_net do
  name "pzskc383.net"
  zone :pzskc383_net
  mx hosts: [:f0rk, :airstrip3]  # auto-assigns priorities by order
end

site :site_box_post do
  domains "post.b0x.pw", "mail.b0x.pw"
  hosts :f0rk
  uses_cert :b0x_wildcard
end
```

Then queries:

```ruby
Infra.cert(:mail_pzskc383).services
# => [Service<smtpd@f0rk>, Service<smtpd@airstrip3>]

Infra.host(:f0rk).ports_to_open
# => [25, 587, 443, 80, 5222, ...]

Infra.zone(:pzskc383_net).mx_records
# => [MX(10, f0rk.pzskc383.net), MX(20, airstrip3.pzskc383.net)]

Infra.zone(:pzskc383_net).tlsa_records
# => [TLSA(_25._tcp.mail, ...), TLSA(_443._tcp.www, ...)]
```

## Integration with Mitamae

Option A: **DSL generates node.json**
- Ruby DSL runs before mitamae
- Outputs structured data to node.json
- Mitamae templates just iterate

Option B: **DSL generates recipes**
- Ruby DSL generates .rb recipe files
- More complex, probably overkill

Option C: **Hybrid**
- DSL loaded at mitamae runtime via `lib/infra.rb`
- Cookbooks query the model directly

## Open Questions

1. Where do secrets live? Still in sops files, loaded separately?

2. How to handle host-specific overrides? (e.g., f0rk has more services than airstrip3)

3. Validation: how to ensure referential integrity? (e.g., cert references zone that exists)

4. Migration path: how to incrementally adopt without rewriting everything?

5. Is this overkill for 2 hosts? (Probably. But it's also an exercise in modeling.)

## Next Steps

1. [ ] Define the core entity structs in Ruby
2. [ ] Build a minimal DSL that can express hosts, zones, certs
3. [ ] Write a "compiler" that outputs node.json compatible data
4. [ ] Migrate one relationship (e.g., mail MX records) as proof of concept
5. [ ] Evaluate: is this better or just different complexity?
