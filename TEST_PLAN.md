# Test Infrastructure Implementation Plan

## Goals

**Primary goal:** Test mitamae configurations in isolated environment before deploying to production.

**Success criteria:**
- Can deploy full DNS/mail/HTTP stack to local VMs
- Can verify mail flow (inbound, outbound, filtering)
- Can verify DNS (zones, DNSSEC, zone transfers)
- Can verify ACME certificate workflow (issuance, TLSA records, service reloads)
- Tests run without internet access (network isolation)

## What We're Testing

### In Scope

**DNS (knot):**
- Zone loading on primary (f0rk)
- DNSSEC signing (KSK/ZSK management)
- Zone transfer to secondary (airstrip3)
- TLSA record publication
- Cross-zone references (pzskc383.net ↔ b0x.pw)

**Mail (smtpd + dovecot):**
- Outbound delivery (f0rk → external-mx)
- Inbound delivery (external-mx → f0rk)
- DANE/TLSA validation
- DKIM signing
- SPF/DMARC validation
- Sieve filtering rules
- Mail routing to dovecot via LMTP
- IMAP access

**Mail edge cases:**
- Greylisting behavior
- Rate limiting
- Spam filtering
- Invalid recipients (bounce handling)
- MX failover (f0rk down → airstrip3)

**Certificates (lego):**
- ACME HTTP-01 challenge
- Certificate issuance from local CA
- TLSA record generation
- Service reload notifications (smtpd, httpd, prosody)

**HTTP (httpd):**
- Basic HTTP serving
- TLS termination
- Virtual host routing

**Base system (openbsd_server, openbsd_admin):**
- Package installation
- File/directory creation
- Service management
- Configuration templating

### Out of Scope (for now)

**Not testing:**
- XMPP/Prosody (complex, lower priority)
- Gopher (low priority)
- WireGuard VPN (needs different network topology)
- Actual spam corpus analysis (can add later)
- Production data migration (separate concern)
- IPv6 (can add later, start with IPv4 only)
- Real Let's Encrypt (use local ACME server)
- Real internet DNS propagation (isolated network)

**Why these are skipped:**
- Start simple, expand later
- Focus on critical services (DNS/mail/HTTP)
- Some require additional infrastructure (spam corpus, IPv6)

## Architecture

### Network Topology

```
libvirt network: test-mitamae (192.168.122.0/24)
  - NO internet access (forward mode='none')
  - Isolated from host network
  - VMs can only talk to each other

VMs:
  - f0rk         192.168.122.10  (primary DNS/mail/web)
  - airstrip3    192.168.122.11  (secondary DNS/mail)
  - external-mx  192.168.122.20  (simulates external mail server)
  - acme-server  192.168.122.30  (local ACME CA - pebble or step-ca)
```

### Host Configuration Strategy

**Use production domains, test IPs:**
- Same domain names: pzskc383.net, b0x.pw, post.b0x.pw
- Same hostnames: f0rk, airstrip3
- Different IPs: 192.168.122.x instead of production IPs
- Network isolation prevents accidental production interaction

**Host config structure:**
```
data/
  hosts/
    f0rk/              # Production config
      default.yml      # Production IPs, SSH config
      secrets.sops.yml # Production secrets

    airstrip3/         # Production config
      default.yml
      secrets.sops.yml

  test-hosts/          # Test configs (NEW)
    f0rk/
      default.yml      # Test IPs (192.168.122.10), simplified
      secrets.yml      # Test secrets (plain, not encrypted)

    airstrip3/
      default.yml      # Test IPs (192.168.122.11)
      secrets.yml

    external-mx/       # Test infrastructure (NEW)
      default.yml

    acme-server/       # Test infrastructure (NEW)
      default.yml
```

**Hocho wrapper for test:**
```bash
# test/hocho-test wrapper script
export HOCHO_INVENTORY=data/test-hosts
exec hocho "$@"
```

Usage:
- Production: `hocho apply f0rk`
- Test: `test/hocho-test apply f0rk`

### Test Infrastructure Components

**external-mx (NEW cookbook):**
- Postfix or OpenSMTPD (decide during implementation)
- DANE/TLSA validation enabled
- Greylisting (spamd)
- Rate limiting
- Mailboxes for test users
- Purpose: Simulates "the internet" for mail testing

**acme-server (NEW cookbook):**
- Pebble (Let's Encrypt test server) OR step-ca
- ACME HTTP-01 challenge support
- Issues certificates to test VMs
- Purpose: Test full cert workflow without real Let's Encrypt

## Testing Strategy

### Test Framework: ServerSpec

**Why ServerSpec:**
- Ruby-based (consistent with mitamae/hocho ecosystem)
- Built on specinfra (same backend concept as mitamae)
- Designed for infrastructure testing
- Good assertions and reporting

**Test organization:**
```
test/
  spec_helper.rb              # Shared setup (SSH config, helpers)
  integration/
    dns_spec.rb               # DNS: zones, DNSSEC, AXFR
    mail_outbound_spec.rb     # f0rk → external-mx
    mail_inbound_spec.rb      # external-mx → f0rk
    mail_filtering_spec.rb    # Sieve rules, spam detection
    mail_failover_spec.rb     # MX failover scenarios
    acme_spec.rb              # Cert issuance, TLSA, reloads
    http_spec.rb              # Basic HTTP/TLS serving
    services_spec.rb          # Service health checks
```

### Test Data / Fixtures

```
test/
  fixtures/
    mail/
      spam/           # Sample spam emails (.eml files)
        viagra.eml
        phishing.eml

      ham/            # Legitimate emails
        normal.eml
        important.eml

    users.yml         # Test user accounts
```

**Test users defined in test config:**
```yaml
# data/test-vars/test-users.yml
test_mail_users:
  - username: testuser1
    password: testpass123
  - username: testuser2
    password: testpass456
```

### Orchestration: Shell Scripts

**No Make, no Rake - just shell scripts:**

```
test/
  create-network.sh   # Create libvirt network
  create-vms.sh       # Create all test VMs
  deploy.sh           # Deploy configs with hocho-test
  run-tests.sh        # Run serverspec tests
  cleanup.sh          # Destroy VMs and network
  all.sh              # Full cycle: create → deploy → test → cleanup
```

**Why shell scripts:**
- Simple, obvious
- No build system needed (not building artifacts)
- Just sequential command execution
- Easy to debug

## Implementation Phases

### Phase 0: Prerequisites
**Goal:** Set up basic infrastructure

**Tasks:**
- [ ] Install required packages on laptop
  - libvirt / qemu
  - virt-install
  - serverspec gem (`gem install serverspec`)
  - swaks (for mail testing)
  - dig / drill (DNS testing)

- [ ] Create base OpenBSD VM image
  - Manual install OR packer template
  - SSH key auth configured
  - Minimal packages (OpenBSD base)
  - Can be reused for all test VMs

**Deliverables:**
- Base OpenBSD qcow2 image
- Documentation on recreating image

---

### Phase 1: Network and VM Infrastructure
**Goal:** Create isolated test environment

**Tasks:**
- [ ] Create libvirt network definition
  - File: `test/network.xml`
  - No internet forwarding
  - Static DHCP for test VMs
  - DNS passthrough disabled

- [ ] Write VM creation script
  - File: `test/create-vms.sh`
  - Creates 4 VMs from base image
  - Assigns IPs via libvirt network
  - Starts VMs

- [ ] Write network creation script
  - File: `test/create-network.sh`
  - Defines and starts libvirt network

- [ ] Write cleanup script
  - File: `test/cleanup.sh`
  - Destroys VMs
  - Destroys network

**Validation:**
- [ ] Can create VMs: `./test/create-vms.sh`
- [ ] Can SSH to VMs: `ssh root@192.168.122.10`
- [ ] VMs have NO internet: `ssh root@192.168.122.10 'ping -c1 8.8.8.8'` fails
- [ ] VMs can ping each other: `ssh root@192.168.122.10 'ping -c1 192.168.122.11'` works

**Deliverables:**
- Working test VM infrastructure
- Scripts to create/destroy VMs

---

### Phase 2: Test Host Configurations
**Goal:** Create test versions of production configs

**Tasks:**
- [ ] Create test inventory structure
  - Directory: `data/test-hosts/`
  - Subdirs: `f0rk/`, `airstrip3/`, `external-mx/`, `acme-server/`

- [ ] Create test-f0rk config
  - File: `data/test-hosts/f0rk/default.yml`
  - Based on production f0rk
  - Test IPs: 192.168.122.10
  - Simplified run_list (skip prosody/gopher initially)
  - Same domains (pzskc383.net, b0x.pw)

- [ ] Create test-airstrip3 config
  - File: `data/test-hosts/airstrip3/default.yml`
  - Based on production airstrip3
  - Test IPs: 192.168.122.11

- [ ] Create test secrets
  - Files: `data/test-hosts/*/secrets.yml` (plain YAML, not encrypted)
  - Test passwords, SSH keys
  - Simplified (no real secrets needed)

- [ ] Create hocho-test wrapper
  - File: `test/hocho-test`
  - Points hocho at `data/test-hosts/`
  - Wrapper around hocho binary

**Validation:**
- [ ] hocho-test can list hosts: `./test/hocho-test list`
- [ ] Shows test-specific IPs in host properties

**Deliverables:**
- Test host configurations
- Wrapper to use test inventory

---

### Phase 3: External Infrastructure Cookbooks
**Goal:** Create test support services

**Tasks:**
- [ ] Create external-mx cookbook
  - Directory: `cookbooks/external-mx/`
  - Install postfix (or smtpd - decide during impl)
  - Configure as mail receiver for test domains
  - Enable DANE/TLSA validation
  - Configure greylisting (spamd)
  - Create test mailboxes
  - Open ports in pf

- [ ] Create acme-server cookbook
  - Directory: `cookbooks/acme-server/`
  - Install pebble OR step-ca (decide during impl)
  - Configure ACME endpoint
  - Generate self-signed CA cert
  - Serve ACME on HTTP/HTTPS
  - Open ports in pf

- [ ] Create external-mx host config
  - File: `data/test-hosts/external-mx/default.yml`
  - IP: 192.168.122.20
  - Run list includes external-mx cookbook

- [ ] Create acme-server host config
  - File: `data/test-hosts/acme-server/default.yml`
  - IP: 192.168.122.30
  - Run list includes acme-server cookbook

**Validation:**
- [ ] Can deploy external-mx: `./test/hocho-test apply external-mx`
- [ ] Can deploy acme-server: `./test/hocho-test apply acme-server`
- [ ] ACME server responds: `curl http://192.168.122.30:14000/dir`
- [ ] SMTP accepts connection: `nc 192.168.122.20 25`

**Deliverables:**
- Working external infrastructure
- New cookbooks for test support

**Decisions needed:**
- Postfix vs OpenSMTPD for external-mx?
  - Postfix: More features, DANE support well-documented
  - OpenSMTPD: Consistent with production, simpler
  - **Recommendation:** OpenSMTPD (consistency)

- Pebble vs step-ca for ACME?
  - Pebble: Designed for testing, lightweight, Go binary
  - step-ca: Full-featured CA, more complex
  - **Recommendation:** Pebble (designed for this exact use case)

---

### Phase 4: Deployment Orchestration
**Goal:** Automate deployment to test VMs

**Tasks:**
- [ ] Write deployment script
  - File: `test/deploy.sh`
  - Deploys in correct order:
    1. external-mx (no dependencies)
    2. acme-server (no dependencies)
    3. f0rk (needs external-mx, acme-server)
    4. airstrip3 (needs f0rk for zone transfer)
  - Uses `./test/hocho-test apply <host>`

- [ ] Update lego cookbook for test CA
  - Detect test environment (check for test CA)
  - Point to acme-server instead of Let's Encrypt
  - Trust test CA certificate

- [ ] Test deployment end-to-end
  - Run `./test/deploy.sh`
  - Verify no errors
  - Check services running on all VMs

**Validation:**
- [ ] All VMs deploy successfully
- [ ] Services start: smtpd, knot, httpd, dovecot
- [ ] No connection errors to external services
- [ ] Certificates issued from test CA

**Deliverables:**
- Working deployment script
- All test VMs configured via mitamae

---

### Phase 5: Test Specifications
**Goal:** Write automated tests

**Tasks:**
- [ ] Set up serverspec
  - File: `test/spec_helper.rb`
  - Configure SSH backends for each host
  - Helper functions for common checks

- [ ] Write DNS tests
  - File: `test/integration/dns_spec.rb`
  - Test: Zone loads on f0rk
  - Test: DNSSEC records present
  - Test: Zone transfers to airstrip3
  - Test: Both zones (pzskc383.net, b0x.pw) work
  - Test: Cross-zone references resolve

- [ ] Write ACME tests
  - File: `test/integration/acme_spec.rb`
  - Test: Certificate requested from pebble
  - Test: Certificate file exists
  - Test: TLSA record published in DNS
  - Test: Services reloaded after cert issuance

- [ ] Write outbound mail tests
  - File: `test/integration/mail_outbound_spec.rb`
  - Test: Send from f0rk to external-mx
  - Test: DKIM signature present
  - Test: SPF validates
  - Test: DANE/TLSA validation succeeds
  - Test: Mail arrives at external-mx

- [ ] Write inbound mail tests
  - File: `test/integration/mail_inbound_spec.rb`
  - Test: Send from external-mx to f0rk
  - Test: Mail delivered via LMTP to dovecot
  - Test: Accessible via IMAP
  - Test: Invalid recipient bounces

- [ ] Write mail filtering tests
  - File: `test/integration/mail_filtering_spec.rb`
  - Test: Sieve rules apply correctly
  - Test: Spam patterns rejected/filtered
  - Test: Ham delivered normally

- [ ] Write service health tests
  - File: `test/integration/services_spec.rb`
  - Test: All services running (smtpd, knot, httpd, dovecot)
  - Test: Ports listening (25, 53, 80, 143, 587)
  - Test: Processes owned by correct users

**Validation:**
- [ ] All tests pass: `rspec test/integration/`
- [ ] Tests detect failures (break something, verify test fails)

**Deliverables:**
- Comprehensive test suite
- Automated validation of infrastructure

---

### Phase 6: Integration and Documentation
**Goal:** Polish and document

**Tasks:**
- [ ] Write orchestration script
  - File: `test/all.sh`
  - Runs: create-network → create-vms → deploy → run-tests
  - Option for cleanup at end

- [ ] Write test execution script
  - File: `test/run-tests.sh`
  - Runs all serverspec tests
  - Pretty output / summary

- [ ] Document test environment
  - File: `test/README.md`
  - Architecture diagram
  - How to run tests
  - How to add new tests
  - Troubleshooting common issues

- [ ] Document VM image creation
  - File: `test/VM-IMAGE.md`
  - How to create base image
  - Required packages
  - SSH key setup

- [ ] Add test fixtures
  - Directory: `test/fixtures/mail/`
  - Sample spam/ham emails
  - Test user definitions

**Validation:**
- [ ] Fresh clone of repo can run tests (following README)
- [ ] Tests run repeatably (destroy → recreate → test)

**Deliverables:**
- Complete, documented test environment
- Runbook for test execution

---

## Success Metrics

**Test environment is successful when:**
- [ ] Can deploy full stack to test VMs without errors
- [ ] All serverspec tests pass
- [ ] Can send mail from f0rk → external-mx with DANE validation
- [ ] Can receive mail at f0rk from external-mx
- [ ] Can test mail filtering rules safely
- [ ] Certificate workflow works (ACME → TLSA → reload)
- [ ] DNS zone transfers work (f0rk → airstrip3)
- [ ] Tests run without internet access
- [ ] Full test cycle completes in < 30 minutes

**Long-term goals (beyond initial implementation):**
- [ ] CI integration (GitHub Actions / local CI)
- [ ] Test coverage for prosody/XMPP
- [ ] IPv6 support in test environment
- [ ] Automated spam corpus testing
- [ ] Performance/load testing
- [ ] Disaster recovery validation (restore from backup)

---

## Risks and Mitigations

**Risk: Test and production configs diverge**
- Mitigation: Regular test runs, same cookbooks for both
- Mitigation: Periodic "test production deploy to test env"

**Risk: Network isolation fails, touches production**
- Mitigation: libvirt network with no forwarding
- Mitigation: pf rules blocking outbound on test VMs
- Mitigation: Different SSH ports/keys for test vs prod
- Mitigation: Use test CA (can't get real Let's Encrypt certs)

**Risk: Test environment too complex to maintain**
- Mitigation: Start minimal (DNS/mail only)
- Mitigation: Document everything
- Mitigation: Automate VM creation (ephemeral, reproducible)

**Risk: Base image becomes stale**
- Mitigation: Document image creation process
- Mitigation: Periodic rebuild (quarterly?)
- Mitigation: Consider packer for automation

**Risk: Tests become flaky**
- Mitigation: Proper wait/retry logic (email delivery delays)
- Mitigation: Clean VM state each run (ephemeral VMs)
- Mitigation: Explicit test ordering (ACME before mail)

---

## Open Questions (to resolve during implementation)

**Phase 3 decisions:**
- [ ] Postfix or OpenSMTPD for external-mx?
- [ ] Pebble or step-ca for ACME server?
- [ ] How to distribute test CA cert to test VMs?

**Configuration questions:**
- [ ] How to handle hocho inventory switching? (wrapper script? environment var?)
- [ ] Where to store test CA certificates? (data/test-vars/?)
- [ ] Should test configs be encrypted? (probably not, but decide)

**Testing questions:**
- [ ] How long to wait for mail delivery? (5s? 10s?)
- [ ] How to test greylisting without long waits? (shorten timeout in test?)
- [ ] Should tests clean up after themselves? (delete sent emails?)

**Infrastructure questions:**
- [ ] Serial console or SSH only for VMs?
- [ ] Persistent disk vs ephemeral? (ephemeral, but document)
- [ ] How much disk/RAM per VM? (512MB RAM, 8GB disk?)

---

## Timeline Estimate

**Realistic timeline for solo implementation:**

- Phase 0 (Prerequisites): 1 day
- Phase 1 (Network/VMs): 1 day
- Phase 2 (Test configs): 1 day
- Phase 3 (External infra): 2 days (new cookbooks)
- Phase 4 (Deployment): 1 day
- Phase 5 (Tests): 3 days (most work here)
- Phase 6 (Documentation): 1 day

**Total: ~10 days** (with some slack for debugging)

**Minimum viable test environment (skip some tests):** ~5 days

---

## Next Steps

**Immediate actions:**
1. Review this plan, adjust as needed
2. Start Phase 0: Install prerequisites
3. Create base OpenBSD VM image (can be manual for now)
4. Begin Phase 1: Network and VM scripts

**Questions to answer before starting:**
- Does this plan make sense?
- Any major gaps or concerns?
- Should we skip anything to ship faster?
- Should we add anything critical that's missing?
