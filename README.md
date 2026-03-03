# configuration cookbooks for a personal openbsd server

## what's here

set of MItamae cookbooks for setting up usual server with self-hosted internet stuff.

we have: DNS, email(send/email/filter), HTTP(s), git, gopher, xmpp.

I used to use ansible for this, but MItamew is more flexible and.. well.. **FUN**!

## rules

- try to use base system, keep intalled packages and deps in general to minimum.
- no php. just no.
- preferrably no rust/go 50Mb static binaries. keep it simple.
- be standards compliant.
- security: don't allow ssh logins except administrative root login.
only with pubkeys and only on distinguished port.

## repo structure
- cookbooks live in `cookbooks/` on main branch.
- host data lives in `data/` on main branch.
  - `data/vars/` is for yaml files that gets included for every host
  - `data/hosts/<hostname>` is host-specific directories.
  - files ending with .sops.yaml are encrypted/decrypted with `sops` before cookbook application.
  - `lib/` has monkey-patches for mitamae
- orphan branches
  - `notes` - misc project documentation and whatever LLMs think they need.
  - `dist` mitamae binaries living in own branch.
- submodule/subtree use
  - used for `resource-cron` mitamae plugin (external).
  - used to pull mitamae sources for reference (using own fork with 4-line diff to upstream that adds mirb binary)
  - used to pull example mitamae projects i found on github for reference.
  - `notes` and `dist` branches of this very repo referenced as subtrees and put in misc/ by rake
  - TL;DR - run `rake prepare` before deploying and run `rake prepare:examples` when you want to get references.
- documenation is either RIGHT HERE in README.md on master or inside detached `notes` branch (should be mounted at misc/notes).
    - yes, Claudie, your `CLAUDE.md` is rigth there, at misc/notes/CLAUDE.md, go ahead and read it.
## cookbooks overview and rough status
- openbsd\_server
  - sets up basic openbsd server stuff
  - reasonable and secure defaults
- openbsd\_admin
  - stuff useful for console access
  - vim, htop, ncdu, doas, `HISTFILE`
- pf
  - PF firewall configuration
  - defines.rb has defines for opening up ports from other cookbook.
  - configurable logging to pflog
  - TODO: actually react on those log
  - TODO: collect label statistic somewhere
  - TODO: debug count of resource invocations
- openbsd\_wireguard
  - sets up internal backbone network on wireguard
  - TODO: not really used yet for anything
- knot
  - authoritativve DNS server hosting zones.
  - proper primary/secondary setup with AXFR
  - TODO: my zones are hardcoded in templates. they should be moved away from knot cookbook into their own zone cookbooks.
  - TODO: knot journal on prod seems to be big, re-check
  - TODO: traffic monitoring
  - TODO: make different keys for lego updates and axfr
- lego
  - ACME certificate issuer.
  - not using built-in acme-client used because i need dns-01 auth for wildcard domains.
  - TODO: publish tlsa records on cert issue
  - TODO: try ecdsa certificates.
  - TODO: link together certificates and server's they use
  - TODO: right now cert data is hardcoded (in a `lego.sops.yaml` for primary server). this could be made as define that specifies needed domains which we later combine into certificate and issue.
- smtpd
  - mail _moving_ daemon.
  - TODO: this cookbooks actually concerns itself with smtpd server itself, mail domains and mail accounts. this could be split in 3 different cookbooks. at least.
  - TODO: verify secondary relay works
  - TODO: verify root mail goes from secondary to primary (and even on primary)
  - TODO: mail filtering. for real.
    - TODO: fcrdns check
    - TODO: spf checks (not `opensmtpd-filter-spf` because it hard blocks instead of adding header so we can act later). need to write something awk with `smptctl spf walk`
    - TODO: mapping between sending email for domain and EHLO host we introduce ourselves with. right now FQDN goes into every field.
    - TODO: dkim checks? dkim checks.
    - TODO: integrate bogofilter as an LDA
  - TODO: mailing lists? yeah, maybe.
- dovecot
  - mail _reading_ daemon
  - same users as smtpd, plain text encrypted file.
  - ideally - as featureful as gmail. for starters - proper sorting and user-accessible sieve filters.
  - TODO: verify mailbox autoconfiguration
  - TODO: fix acl errors or disable module
  - TODO: integrate spam filtering based on smptd filters result that they put in email headers.
  - TODO: shared mailboxes for public-inbox mirrors and (? per-user) rss2email feeds.
- httpd
  - actually relayd + httpd.
  - httpd listens on 16080 ("http" port, responding to configured unencrypted sites and doing redirects to https) and 16081 ("https" port, real serving stuff)
  - TODO: maybe move logging to syslog
- prosody
  - XMPP server. for talking to people.
  - TODO: currently userbase is completely different from email one
  - TODO: run compliance checks
- site\_main
  - cookbooks for setting up my main site - pzskc383.net
  - TODO: jokes on you, it actually sets up git, and it's like 80% of it's code
  - TODO: move git setup out of here
- site\_fqdn
  - sets up default page to respond when we're answering to `Host:` equal to our fqdn, or our public ipv4/v6 addresses.
    - a simple webpage with abuse reporting email address.
    - and maybe bit of 'YOU'VE BEEN MONITORED' vibe.
    - TODO: maybe do it for default server too?
    - TOOD: return `text/plain` contenttype for extra cool.
- site\_box\_main
  - `b0x.pw` - main landing page for b0x.pw services
- site\_box\_boot
  - `boot.my.b0x.pw` - netboot service. files served by httpd, that's it.
  - TODO: so far no custom configs, just deployed netboot.xyz on `x.` subdomain.
- site\_box\_post
  - `post.b0x.pw` mail service langing page
  - TODO: describe it
- site\_box\_talk
  - `talk.b0x.pw` xmpp service langing page
  - TODO: describe it too
- dickd
  - draws crude penis erection animation over telnet.
  - TODO: nothing. it's perfect.
  - TODO: investigate plugging it as `rdr-to` target for bad hosts to feed them ascii penises instead of real service data.
  - TODO: also, plug as a shell in sshd
- gopher
  - a very simple gopher serving page.
- openbsd\_com0
  - small cookbook for using console access on /dev/tty0.
  - TODO: remove me. it was used when i VPS servers with serial console access. i don't anymore.
- ldap
  - relevant code lives in `feature/ldap` branch for now
  - sets up builtin base ldapd daemon to keep userbase singular between different services (so far prosody+xmpp+smptd)
    - using custom schema that has just username and password field. don't put our real configuration objects there. just auth.
    - TODO: main reason is ability to self-change passwords for users.
    - TODO: not reqally used yet. just sets up records, not plugged in yet.
    - TOOD: needs verification authenticating from outside the machine (y tho, we don't login anywhere on secondary)
    - TODO: probably no ypldap/nis integration, i.e. no posixAccount ldap objects. user's still can't login.
