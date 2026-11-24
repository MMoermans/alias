# alias

Shell aliases and small helper functions for bash and zsh, on Linux (Debian, Arch/CachyOS) and macOS.

```bash
git clone https://github.com/MMoermans/alias.git ~/alias
echo 'source ~/alias/aliases.sh' >> ~/.bashrc    # or ~/.zshrc
```

Sourcing the file prints nothing, and aliases are only defined when the command behind them exists,
so the same line is safe on every machine.

## What you get

| | | |
|---|---|---|
| `cp` `mv` `ln` | `-i` | Ask before overwriting a file |
| `c` | `clear` | |
| `..` `...` | `cd ..` `cd ../..` | |
| `untar file` | `tar -xvf` | Detects `.tar`, `.gz`, `.bz2`, `.xz` and `.zst` by itself |
| `sha file` | `sha256sum` (`shasum -a 256` on macOS) | SHA-256 of a file |
| `getpass` | `openssl rand -base64 20` | Random 28 character password |
| `ipe` | function | Public IP address, from ipinfo.io |
| `ipi` | function | Local IP address of the interface with the default route |
| `ports` | `ss -tulpn` on Linux, `lsof -iTCP -sTCP:LISTEN -n -P` on macOS | Listening ports and their programs. Use `sudo` to see other users' programs |
| `ipt` | `sudo iptables -L -n -v --line-numbers` | Firewall rules with counters (Linux) |
| `update` | `apt-get`, `pacman -Syu` or `brew`, whichever exists | Update the system |

## CTI helpers

An optional second file, `cti.sh`. Load it next to the first one, then run `ctihelp` for the list:

```bash
echo 'source ~/alias/cti.sh' >> ~/.bashrc    # or ~/.zshrc
```

Every command is tagged by how much it exposes you. Sourcing the file prints nothing and needs no extra tools;
a command that needs one (`dig`, `jq`, `zip`, ...) says so when you run it.

| Tag | Meaning |
|---|---|
| **local** | Works on your own data, no network |
| **links** | Only prints URLs. Nothing is contacted until you open them |
| **passive** | A third party (your resolver, crt.sh, Team Cymru) sees what you ask about |
| **active** | Contacts the target directly, so your IP shows up in their logs. A notice is printed each time |

**Defang and extract (local).** Input can be defanged already, and every extractor reads files or stdin.

| Command | |
|---|---|
| `defang`, `refang` | Defang or refang values or stdin. Uses the [Defanger](https://github.com/MMoermans/Defanger) tool when installed; the built-in fallback defangs every dot, so use it on lists, not prose |
| `ips` `urls` `emails` `md5s` `sha1s` `sha256s` `cves` `ttps` | The unique indicators in a file or stdin. IPs are range-checked, hashes lower-cased, CVEs upper-cased |
| `domains` | Needs Defanger: a plain pattern cannot tell `evil.com` from `setup.py` |
| `iocs` | All of them as `type<TAB>value` |
| `freq` | Count and rank: `ips access.log \| freq` |
| `hashes file...` | MD5, SHA-1 and SHA-256, ready for a report |
| `strs file` | Printable strings of a binary (never run what you are triaging) |
| `malzip`, `malunzip` | Zip with the password `infected`, the usual way to share a sample (the zip encryption is a speed bump for scanners, not protection) |
| `utc`, `fromepoch`, `toepoch` | UTC timestamps in report format; Unix seconds or milliseconds |
| `b64e` `b64d` `urle` `urld` `rot13` | Encode and decode |

`ttps` pipes into [mitre-generator](https://github.com/MMoermans/mitre_generator): `ttps report.txt | mitre-generator -`.

**Links.** `ioc` works out what an indicator is and prints where to look it up, `ioco` opens the same links.

```console
$ ioc 8[.]8[.]8[.]8 CVE-2024-3094
8[.]8[.]8[.]8
  VirusTotal      https://www.virustotal.com/gui/ip-address/8.8.8.8
  AbuseIPDB       https://www.abuseipdb.com/check/8.8.8.8
  Shodan          https://www.shodan.io/host/8.8.8.8
  GreyNoise       https://viz.greynoise.io/ip/8.8.8.8
CVE-2024-3094
  NVD             https://nvd.nist.gov/vuln/detail/CVE-2024-3094
  CVE.org         https://www.cve.org/CVERecord?id=CVE-2024-3094
```

It understands hashes (MD5, SHA-1, SHA-256), IPv4 and IPv6, domains, URLs (it links the host), CVEs and AS numbers.
`attack T1059.001 G0007 TA0001` prints the MITRE ATT&CK page for a technique, tactic, group, software, mitigation,
campaign or data source.

**Passive and active.**

| Command | Tag | |
|---|---|---|
| `asn ip` | passive | Origin AS, number and name, from Team Cymru's DNS service (needs `dig`) |
| `rdns ip`, `dnsq domain` | passive | Reverse DNS; A, AAAA, MX, NS and TXT records (needs `dig`) |
| `crt domain` | passive | Hostnames in certificates issued for a domain, from crt.sh (needs `curl` and `jq`) |
| `cert host [port]` | active | Subject, issuer, dates, fingerprint and names of a TLS certificate |
| `heads url` | active | Response headers, following redirects |

## What changed in this cleanup

- `ipi` used `ifconfig getifaddr en0`, which is not a real command (the macOS one is `ipconfig`), and it
  was hard-wired to one interface. It now finds the interface from the default route, on Linux and macOS.
- `ipe` asked ipinfo.io over plain HTTP and printed no newline. It uses HTTPS and ends the line.
- `ports` used `netstat`, which is deprecated and missing on current systems. It uses `ss` (Linux) or `lsof` (macOS).
- `ipt` carried a comment saying it displayed all rules, but it only ran `iptables`. It now lists the rules.
- `untar` only handled `.tar.gz`. `update` only handled Debian, and now also Arch/CachyOS and Homebrew.
- Linux and macOS commands were mixed in one list (`apt-get`, `iptables`, `shasum`, `en0`). They are now
  picked by OS or by what is installed.

## Tests

```bash
bash tests/test.sh
```

Checks the line endings, that bash and zsh can source both files quietly, that every alias points at a command
that exists, that every CTI command is in `ctihelp`, and that `sha`, `untar`, `getpass`, `ipi` and the whole
offline CTI toolkit really work (the lookups that need the network are not run in CI). CI runs it on Ubuntu and macOS.
