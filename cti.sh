# shellcheck shell=bash
# Handy commands for cyber threat intelligence work, for bash and zsh on Linux and macOS.
#
#   source /path/to/cti.sh            # add to ~/.bashrc or ~/.zshrc, next to aliases.sh
#   ctihelp                           # list everything
#
# Every command says how much it exposes you:
#   [local]   works on your own data, no network
#   [links]   only prints URLs, nothing is contacted until you open them
#   [passive] a third party (resolver, crt.sh, Team Cymru) sees what you ask about
#   [active]  contacts the target directly. It prints a notice each time.
#
# Sourcing this file prints nothing and needs no extra tools. Commands that need something
# (dig, jq, zip, ...) say so when you run them.

# --- Internals -----------------------------------------------------------------------------
# Arguments, or stdin when there are none
_in() { if [ $# -gt 0 ]; then printf '%s\n' "$@"; else cat; fi; }

# Undo the usual defanging styles on stdin
_refang() {
  sed -E 's/\[\.\]|\(\.\)|\{\.\}|\[dot\]|\(dot\)/./g; s/h(xx|XX)p/http/g; s/\[@\]|\(@\)|\[at\]|\(at\)/@/g; s/\[:\]|\(:\)/:/g'
}

# Files named as arguments, or stdin, refanged
_clean() { cat -- "$@" | _refang; }

_need() { command -v "$1" >/dev/null 2>&1 || { echo "$2: needs $1" >&2; return 1; }; }

_active() { echo "note: this contacts $1 directly (your IP will show up in their logs)" >&2; }

_open() { if command -v open >/dev/null 2>&1; then open "$1"; else xdg-open "$1" >/dev/null 2>&1; fi; }

# --- Defang and refang ---------------------------------------------------------------------
# [local] defang 1.2.3.4 http://evil.com/a     or     cat iocs.txt | defang
# Uses the defanger tool when it is installed (it understands full text). The fallback defangs
# every dot, so use it on lists of indicators, not on prose.
defang() {
  if command -v defanger >/dev/null 2>&1; then defanger defang "$@"
  else _in "$@" | sed -E 's/http/hxxp/g; s/\./[.]/g; s/@/[@]/g'; fi
}

refang() {
  if command -v defanger >/dev/null 2>&1; then defanger refang "$@"
  else _in "$@" | _refang; fi
}

# --- Extract indicators from files or stdin (defanged input is fine) -------------------------
# [local] ips report.txt       cat report.txt | urls
ips() {
  _clean "$@" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' \
    | awk -F. '$1 < 256 && $2 < 256 && $3 < 256 && $4 < 256' | sort -u
}

urls() {
  local re="https?://[^[:space:]<>\"')]+"
  _clean "$@" | grep -Eio "$re" | sed -E 's/[.,;:!?]+$//' | sort -u
}

emails() { _clean "$@" | grep -Eio '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' | tr 'A-Z' 'a-z' | sort -u; }

# Domains need the defanger tool: a plain pattern cannot tell evil.com from setup.py
domains() {
  command -v defanger >/dev/null 2>&1 || { echo "domains: needs defanger (github.com/MMoermans/Defanger)" >&2; return 1; }
  defanger extract --only domain --live "$@" 2>/dev/null
}

md5s()    { _clean "$@" | grep -Eow '[a-fA-F0-9]{32}' | tr 'A-F' 'a-f' | sort -u; }
sha1s()   { _clean "$@" | grep -Eow '[a-fA-F0-9]{40}' | tr 'A-F' 'a-f' | sort -u; }
sha256s() { _clean "$@" | grep -Eow '[a-fA-F0-9]{64}' | tr 'A-F' 'a-f' | sort -u; }
cves()    { _clean "$@" | grep -Eio 'CVE-[0-9]{4}-[0-9]{4,}' | tr 'a-z' 'A-Z' | sort -u; }
# MITRE ATT&CK technique ids. Pipes straight into mitre-generator
ttps()    { _clean "$@" | grep -Eow 'T[0-9]{4}(\.[0-9]{3})?' | sort -u; }

# Everything at once, as "type<TAB>value"
iocs() {
  local t
  t="$(_clean "$@")"
  printf '%s\n' "$t" | ips     | awk '{ print "ipv4\t" $0 }'
  printf '%s\n' "$t" | urls    | awk '{ print "url\t" $0 }'
  printf '%s\n' "$t" | emails  | awk '{ print "email\t" $0 }'
  if command -v defanger >/dev/null 2>&1; then printf '%s\n' "$t" | domains | awk '{ print "domain\t" $0 }'; fi
  printf '%s\n' "$t" | md5s    | awk '{ print "md5\t" $0 }'
  printf '%s\n' "$t" | sha1s   | awk '{ print "sha1\t" $0 }'
  printf '%s\n' "$t" | sha256s | awk '{ print "sha256\t" $0 }'
  printf '%s\n' "$t" | cves    | awk '{ print "cve\t" $0 }'
  printf '%s\n' "$t" | ttps    | awk '{ print "attack\t" $0 }'
}

# Count and rank lines: ips log.txt | freq
alias freq='sort | uniq -c | sort -rn'

# --- Files -----------------------------------------------------------------------------------
_hash() { # _hash md5|sha1|sha256 file
  case "$1" in
    md5)    if command -v md5sum >/dev/null 2>&1; then md5sum "$2" | awk '{ print $1 }'; else md5 -q "$2"; fi ;;
    sha1)   if command -v sha1sum >/dev/null 2>&1; then sha1sum "$2" | awk '{ print $1 }'; else shasum -a 1 "$2" | awk '{ print $1 }'; fi ;;
    sha256) if command -v sha256sum >/dev/null 2>&1; then sha256sum "$2" | awk '{ print $1 }'; else shasum -a 256 "$2" | awk '{ print $1 }'; fi ;;
  esac
}

# [local] MD5, SHA-1 and SHA-256 of each file, ready to paste into a report
hashes() {
  local f
  [ $# -gt 0 ] || { echo "usage: hashes file..." >&2; return 2; }
  for f in "$@"; do
    printf '%s\n' "$f"
    printf '  md5     %s\n' "$(_hash md5 "$f")"
    printf '  sha1    %s\n' "$(_hash sha1 "$f")"
    printf '  sha256  %s\n' "$(_hash sha256 "$f")"
  done
}

# [local] Printable strings of a binary. Never run what you are triaging
if command -v strings >/dev/null 2>&1; then alias strs='strings -a -n 8'; fi

# [local] Share a sample the usual way: a zip with the password "infected".
# (The classic zip encryption is a speed bump for scanners, not real protection.)
malzip() {
  local f
  _need zip malzip || return 1
  for f in "$@"; do zip -q -j -P infected "$f.zip" "$f" && echo "$f.zip"; done
}

# [local] Unpack such a zip into the current directory. It extracts malware: use a VM
malunzip() {
  local z
  _need unzip malunzip || return 1
  for z in "$@"; do unzip -q -o -P infected "$z"; done
}

# --- Look indicators up: links only ----------------------------------------------------------
# One "label<TAB>url" per line for an indicator (defanged input is fine)
_links() {
  local x="$1" h u cve re_md5 re_sha1 re_sha256 re_ip re_ip6 re_dom re_cve re_asn
  re_md5='^[a-fA-F0-9]{32}$'; re_sha1='^[a-fA-F0-9]{40}$'; re_sha256='^[a-fA-F0-9]{64}$'
  re_ip='^([0-9]{1,3}\.){3}[0-9]{1,3}$'; re_ip6='^[0-9a-fA-F]*:[0-9a-fA-F:]+$'
  re_dom='^([A-Za-z0-9-]+\.)+[A-Za-z]{2,}$'; re_cve='^[Cc][Vv][Ee]-[0-9]{4}-[0-9]{4,}$'
  re_asn='^[Aa][Ss][0-9]+$'
  x="$(printf '%s' "$x" | _refang)"

  if [[ $x =~ $re_md5 || $x =~ $re_sha1 || $x =~ $re_sha256 ]]; then
    x="$(printf '%s' "$x" | tr 'A-F' 'a-f')"
    printf 'VirusTotal\thttps://www.virustotal.com/gui/file/%s\n' "$x"
    printf 'HybridAnalysis\thttps://www.hybrid-analysis.com/search?query=%s\n' "$x"
    if [[ ${#x} -eq 64 ]]; then printf 'MalwareBazaar\thttps://bazaar.abuse.ch/sample/%s/\n' "$x"; fi
  elif [[ $x =~ $re_ip || $x =~ $re_ip6 ]]; then
    printf 'VirusTotal\thttps://www.virustotal.com/gui/ip-address/%s\n' "$x"
    printf 'AbuseIPDB\thttps://www.abuseipdb.com/check/%s\n' "$x"
    printf 'Shodan\thttps://www.shodan.io/host/%s\n' "$x"
    printf 'GreyNoise\thttps://viz.greynoise.io/ip/%s\n' "$x"
  elif [[ $x =~ $re_cve ]]; then
    cve="$(printf '%s' "$x" | tr 'a-z' 'A-Z')"
    printf 'NVD\thttps://nvd.nist.gov/vuln/detail/%s\n' "$cve"
    printf 'CVE.org\thttps://www.cve.org/CVERecord?id=%s\n' "$cve"
  elif [[ $x =~ $re_asn ]]; then
    printf 'bgp.he.net\thttps://bgp.he.net/%s\n' "$(printf '%s' "$x" | tr 'a-z' 'A-Z')"
  elif [[ $x == *"://"* ]]; then
    # a URL: link its host, plus a urlscan search for the URL itself
    h="${x#*://}"; h="${h%%[/?#]*}"; h="${h##*@}"; h="${h%%:*}"
    printf 'urlscan\thttps://urlscan.io/search/#page.url:%%22%s%%22\n' "$x"
    _links "$h"
  elif [[ $x =~ $re_dom ]]; then
    u="$(printf '%s' "$x" | tr 'A-Z' 'a-z')"
    printf 'VirusTotal\thttps://www.virustotal.com/gui/domain/%s\n' "$u"
    printf 'urlscan\thttps://urlscan.io/search/#page.domain:%s\n' "$u"
    printf 'crt.sh\thttps://crt.sh/?q=%s\n' "$u"
  else
    return 1
  fi
}

# [links] ioc 8[.]8[.]8[.]8 evil.com CVE-2024-3094 AS15169 <hash> <url>
ioc() {
  local x label url rc=0
  [ $# -gt 0 ] || { echo "usage: ioc indicator..." >&2; return 2; }
  for x in "$@"; do
    if _links "$x" >/dev/null; then
      printf '%s\n' "$x"
      _links "$x" | while IFS=$'\t' read -r label url; do printf '  %-15s %s\n' "$label" "$url"; done
    else
      echo "ioc: don't know what '$x' is" >&2; rc=1
    fi
  done
  return $rc
}

# [links] Same links, opened in the browser (every site will see the lookup)
ioco() {
  local x label url
  for x in "$@"; do
    _links "$x" | while IFS=$'\t' read -r label url; do _open "$url"; done
  done
}

# [links] MITRE ATT&CK page for technique, tactic, group, software, mitigation, campaign or data source
# attack T1059.001 G0007 TA0001
attack() {
  local id kind rc=0
  [ $# -gt 0 ] || { echo "usage: attack id..." >&2; return 2; }
  for id in "$@"; do
    id="$(printf '%s' "$id" | tr 'a-z' 'A-Z')"
    kind=""
    case "$id" in
      T[0-9][0-9][0-9][0-9]|T[0-9][0-9][0-9][0-9].[0-9][0-9][0-9]) kind=techniques ;;
      TA[0-9][0-9][0-9][0-9]) kind=tactics ;;
      G[0-9][0-9][0-9][0-9]) kind=groups ;;
      S[0-9][0-9][0-9][0-9]) kind=software ;;
      M[0-9][0-9][0-9][0-9]) kind=mitigations ;;
      C[0-9][0-9][0-9][0-9]) kind=campaigns ;;
      DS[0-9][0-9][0-9][0-9]) kind=datasources ;;
    esac
    if [ -n "$kind" ]; then printf 'https://attack.mitre.org/%s/%s/\n' "$kind" "$(printf '%s' "$id" | tr . /)"
    else echo "attack: '$id' is not an ATT&CK id" >&2; rc=1; fi
  done
  return $rc
}

# --- Look indicators up: passive (a third party sees your question) ---------------------------
# [passive] Origin AS of an IPv4 address, from Team Cymru's DNS service. Needs dig
# asn 8.8.8.8
asn() {
  local ip rev line num name
  _need dig asn || return 1
  [ $# -gt 0 ] || { echo "usage: asn ipv4..." >&2; return 2; }
  for ip in "$@"; do
    ip="$(printf '%s' "$ip" | _refang)"
    rev="$(printf '%s' "$ip" | awk -F. 'NF == 4 { print $4 "." $3 "." $2 "." $1 }')"
    [ -n "$rev" ] || { echo "asn: '$ip' is not an IPv4 address" >&2; continue; }
    line="$(dig +short TXT "$rev.origin.asn.cymru.com" | head -1 | tr -d '"')"
    num="$(printf '%s' "$line" | awk -F'|' '{ split($1, a, " "); print a[1] }')"
    if [ -z "$num" ]; then printf '%-16s no origin AS found\n' "$ip"; continue; fi
    name="$(dig +short TXT "AS$num.asn.cymru.com" | head -1 | tr -d '"' | awk -F'|' '{ sub(/^ +/, "", $5); print $5 }')"
    printf '%-16s AS%-8s %-20s %s\n' "$ip" "$num" "$(printf '%s' "$line" | awk -F'|' '{ gsub(/ /, "", $2); print $2 }')" "$name"
  done
}

# [passive] Reverse DNS. Needs dig
rdns() { _need dig rdns || return 1; local ip; for ip in "$@"; do printf '%s  ' "$ip"; dig +short -x "$(printf '%s' "$ip" | _refang)" | paste -sd' ' -; echo; done; }

# [passive] The usual record types of a domain. Needs dig
dnsq() {
  local d t
  _need dig dnsq || return 1
  for d in "$@"; do
    d="$(printf '%s' "$d" | _refang)"
    for t in A AAAA MX NS TXT; do dig +short "$t" "$d" | sed "s/^/$t  /"; done
  done
}

# [passive] Hostnames in certificates issued for a domain, from certificate transparency (crt.sh).
# Needs curl and jq. crt.sh sees the domain you ask about
crt() {
  _need curl crt || return 1
  _need jq crt || return 1
  curl -fsS "https://crt.sh/?q=%25.$(printf '%s' "$1" | _refang)&output=json" | jq -r '.[].name_value' | sort -u
}

# --- Active: these talk to the target ---------------------------------------------------------
# [active] Certificate of a TLS service: cert host [port]
cert() {
  local host port pem
  host="$(printf '%s' "$1" | _refang)"; port="${2:-443}"
  [ -n "$host" ] || { echo "usage: cert host [port]" >&2; return 2; }
  _need openssl cert || return 1
  _active "$host"
  pem="$(openssl s_client -connect "$host:$port" -servername "$host" </dev/null 2>/dev/null | openssl x509 2>/dev/null)"
  [ -n "$pem" ] || { echo "cert: no certificate from $host:$port" >&2; return 1; }
  printf '%s\n' "$pem" | openssl x509 -noout -subject -issuer -dates -fingerprint -sha256
  printf '%s\n' "$pem" | openssl x509 -noout -text | grep -A1 'Subject Alternative Name'
}

# [active] Response headers, following redirects: heads url
heads() { _need curl heads || return 1; _active "the server"; curl -sIL --max-time 10 "$(printf '%s' "$1" | _refang)"; }

# --- Time ---------------------------------------------------------------------------------------
# [local] Now in UTC, in the format reports use
utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# [local] Unix time (seconds or milliseconds) to UTC: fromepoch 1700000000
fromepoch() {
  local e
  for e in "$@"; do
    [ "${#e}" -eq 13 ] && e=$((e / 1000))
    date -u -d "@$e" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -r "$e" +%Y-%m-%dT%H:%M:%SZ
  done
}

# [local] UTC time to Unix time: toepoch 2026-11-24T10:00:00Z
toepoch() {
  local t
  for t in "$@"; do
    date -u -d "$t" +%s 2>/dev/null || date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$t" +%s
  done
}

# --- Decode and encode ----------------------------------------------------------------------------
# [local] b64e hello      echo aGVsbG8= | b64d
# (an argument is encoded exactly as typed; piped input is encoded as it comes, newline included)
b64e() { if [ $# -gt 0 ]; then printf '%s' "$*"; else cat; fi | base64 | tr -d '\n'; echo; }
b64d() {
  local flag=-d
  echo | base64 -d >/dev/null 2>&1 || flag=-D
  _in "$@" | base64 "$flag"
}

# [local] URL encoding and decoding
urle() { _in "$@" | perl -pe 'chomp; s/([^A-Za-z0-9_.~-])/sprintf("%%%02X", ord($1))/ge; $_ .= "\n"'; }
urld() { _in "$@" | perl -pe 's/\+/ /g; s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge'; }

rot13() { _in "$@" | tr 'A-Za-z' 'N-ZA-Mn-za-m'; }

# --- Help ---------------------------------------------------------------------------------------------
ctihelp() {
  cat <<'EOF'
local     defang refang            defang/refang values or stdin (uses 'defanger' when installed)
          ips urls emails md5s     list the indicators in files or stdin; defanged input is fine
          sha1s sha256s cves ttps  domains needs 'defanger'; ttps pipes into mitre-generator
          iocs                     all of them as type<TAB>value
          freq                     count and rank lines:  ips log | freq
          hashes file...           md5, sha1 and sha256
          strs file                printable strings of a binary
          malzip malunzip          zip with the password "infected", and back
          utc fromepoch toepoch    time, in UTC
          b64e b64d urle urld rot13
          ctihelp                  this list
links    ioc indicator...         VirusTotal, AbuseIPDB, Shodan, urlscan, NVD ... links
          ioco indicator...        the same, opened in the browser
          attack id...             MITRE ATT&CK page for T1059.001, G0007, TA0001 ...
passive   asn ip                   origin AS (Team Cymru DNS)
          rdns ip   dnsq domain    reverse DNS, A/AAAA/MX/NS/TXT (your resolver sees it)
          crt domain               hostnames from certificate transparency (crt.sh sees it)
active    cert host [port]         TLS certificate         these contact the target
          heads url                response headers        directly: your IP is logged
EOF
}
