#!/usr/bin/env bash
# shellcheck disable=SC2016  # single-quoted snippets are code for a second shell, nothing may expand here
# Sources aliases.sh in bash (and zsh, when installed) and checks that it behaves.
# Run on Linux or macOS:  bash tests/test.sh
set -u
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
file="$here/aliases.sh"
cti="$here/cti.sh"
os="$(uname -s)"
fails=0

check() { # check <description> <command...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "ok    $desc"; else echo "FAIL  $desc"; fails=$((fails + 1)); fi
}

# --- the file itself ---------------------------------------------------------------------
check "no carriage returns (they break every alias)" bash -c "! grep -q \$'\\r' '$file'"
check "bash can parse it"                           bash -n "$file"
check "cti.sh: no carriage returns"                 bash -c "! grep -q \$'\\r' '$cti'"
check "cti.sh: bash can parse it"                   bash -n "$cti"

# --- sourcing, in each shell --------------------------------------------------------------
want="c .. ... cp mv ln untar sha getpass ports update"
[[ "$os" == Linux ]] && want="$want ipt"
[[ "$os" == Darwin ]] && ! command -v brew >/dev/null 2>&1 && want="${want/update/}"

cti_funcs="defang refang ips urls emails domains md5s sha1s sha256s cves ttps iocs hashes malzip malunzip ioc ioco attack asn rdns dnsq crt cert heads utc fromepoch toepoch b64e b64d urle urld rot13 ctihelp"

for shell in bash zsh; do
  command -v "$shell" >/dev/null 2>&1 || { echo "skip  $shell is not installed"; continue; }
  out="$("$shell" -c ". '$file'" 2>&1)"
  check "$shell: sourcing succeeds"         test $? -eq 0
  check "$shell: sourcing prints nothing"   test -z "$out"
  for name in $want; do
    # update only exists when a package manager does
    if [[ "$name" == update ]] && ! command -v apt-get >/dev/null 2>&1 && ! command -v pacman >/dev/null 2>&1 && ! command -v brew >/dev/null 2>&1; then continue; fi
    check "$shell: alias $name is defined"  "$shell" -c ". '$file'; alias $name"
  done
  check "$shell: ipe and ipi are functions" "$shell" -c ". '$file'; type ipe && type ipi"

  out="$("$shell" -c ". '$file'; . '$cti'" 2>&1)"
  check "$shell: sourcing both files prints nothing" test -z "$out"
  for name in $cti_funcs; do
    check "$shell: cti $name is defined"   "$shell" -c ". '$cti'; type $name"
  done
  check "$shell: cti alias freq is defined" "$shell" -c ". '$cti'; alias freq"
done

# every command is listed in ctihelp, so the help cannot drift from the code
for name in $cti_funcs freq strs; do
  check "ctihelp mentions $name" bash -c ". '$cti'; ctihelp | grep -qw '$name'"
done

# --- every alias points at a command that exists --------------------------------------------
names="$(bash -c ". '$file'; alias" | sed -n "s/^alias \([^=]*\)=.*/\1/p")"
for name in $names; do
  def="$(bash -c ". '$file'; alias '$name'")"
  def="${def#*=}"; def="${def//\'/}"
  read -r -a words <<<"$def"
  cmd="${words[0]}"
  [[ "$cmd" == sudo ]] && cmd="${words[1]}"
  [[ "$cmd" == "$name" ]] && continue          # cp='cp -i' wraps the command of the same name
  check "alias $name -> $cmd exists" env PATH="$PATH:/usr/sbin:/sbin" bash -c "command -v $cmd"
done

# --- behaviour -----------------------------------------------------------------------------
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work" || exit 1

# Run a snippet in a fresh bash that has sourced aliases.sh. Aliases only expand on lines that are
# parsed after the line that defined them, so the source line and the snippet are separate lines.
nl=$'\n'
b() { bash -c "shopt -s expand_aliases${nl}. '$file'${nl}. '$cti'${nl}$1"; }

printf 'abc' >data.txt
check "sha: SHA-256 of 'abc'"  b '[[ "$(sha data.txt)" == ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad* ]]'

mkdir t && echo hello >t/f
tar -czf a.tgz t && tar -cJf a.txz t && rm -rf t
check "untar: .tar.gz"         b 'mkdir x1 && cd x1 && untar ../a.tgz && [[ -f t/f ]]'
check "untar: .tar.xz"         b 'mkdir x2 && cd x2 && untar ../a.txz && [[ -f t/f ]]'

check "getpass: 28 characters" b '[[ $(getpass | tr -d "\n" | wc -c) -eq 28 ]]'
check "ipi: prints an IPv4 address" b 'ipi | grep -Eq "^[0-9]+(\.[0-9]+){3}$"'

# --- CTI helpers ------------------------------------------------------------------------------
export sample='Seen 1.2.3.4 and 5[.]6[.]7[.]8, again 1.2.3.4, bad 999.1.1.1. Mail Bad.Actor[@]Evil[.]com. See hxxp://evil[.]com/x, and https://a.org/b. Hash 900150983CD24FB0D6963F7D28E17F72 and CVE-2024-3094, cve-2021-44228 plus T1059.001 and T1566.'
sha256_abc=ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
export sha256_abc

check "defang a list of indicators"   b '[[ "$(defang 1.2.3.4 http://evil.com/a)" == "1[.]2[.]3[.]4"$'"'"'\n'"'"'"hxxp://evil[.]com/a" ]]'
check "refang the common styles"      b '[[ "$(refang "hxxp://evil[.]com/a" "5(.)6[dot]7[.]8" "a[@]b[.]co")" == "http://evil.com/a"$'"'"'\n'"'"'"5.6.7.8"$'"'"'\n'"'"'"a@b.co" ]]'

check "ips: valid, unique, refanged"  b '[[ "$(printf "%s" "$sample" | ips | paste -sd, -)" == "1.2.3.4,5.6.7.8" ]]'
check "urls: refanged, no trailing punctuation" b 'u="$(printf "%s" "$sample" | urls)"; grep -qFx "http://evil.com/x" <<<"$u" && grep -qFx "https://a.org/b" <<<"$u" && [[ $(wc -l <<<"$u") -eq 2 ]]'
check "emails: lower case, refanged"  b '[[ "$(printf "%s" "$sample" | emails)" == "bad.actor@evil.com" ]]'
check "md5s: lower case"              b '[[ "$(printf "%s" "$sample" | md5s)" == "900150983cd24fb0d6963f7d28e17f72" ]]'
check "cves: upper case, unique"      b '[[ "$(printf "%s" "$sample" | cves | paste -sd, -)" == "CVE-2021-44228,CVE-2024-3094" ]]'
check "ttps: techniques and sub-techniques" b '[[ "$(printf "%s" "$sample" | ttps | paste -sd, -)" == "T1059.001,T1566" ]]'
check "iocs: type and value"          b 'printf "%s" "$sample" | iocs | awk -F"\t" '"'"'$1 == "ipv4" && $2 == "1.2.3.4" { f = 1 } END { exit !f }'"'"
check "extractors read files too"     b 'printf "%s\n" "$sample" >s.txt; [[ "$(ips s.txt | paste -sd, -)" == "1.2.3.4,5.6.7.8" ]]'
check "freq counts and ranks"         b '[[ "$(printf "a\nb\na\n" | freq | head -1 | awk "{ print \$1, \$2 }")" == "2 a" ]]'

check "hashes: md5, sha1 and sha256"  b 'h="$(hashes data.txt)"; grep -q "md5     900150983cd24fb0d6963f7d28e17f72" <<<"$h" && grep -q "sha1    a9993e364706816aba3e25717850c26c9cd0d89d" <<<"$h" && grep -q "sha256  $sha256_abc" <<<"$h"'
check "hashes: needs a file"          b '! hashes 2>/dev/null'

check "attack: technique"             b '[[ "$(attack T1059.001)" == "https://attack.mitre.org/techniques/T1059/001/" ]]'
check "attack: group, tactic, data source (any case)" b '[[ "$(attack g0007 TA0001 DS0017 | paste -sd" " -)" == "https://attack.mitre.org/groups/G0007/ https://attack.mitre.org/tactics/TA0001/ https://attack.mitre.org/datasources/DS0017/" ]]'
check "attack: rejects nonsense"      b '! attack nonsense 2>/dev/null'

check "ioc: hash"                     b 'ioc 900150983cd24fb0d6963f7d28e17f72 | grep -q "virustotal.com/gui/file/900150983cd24fb0d6963f7d28e17f72"'
check "ioc: sha256 also gets MalwareBazaar" b 'ioc "$sha256_abc" | grep -q "bazaar.abuse.ch/sample/$sha256_abc"'
check "ioc: defanged IP"              b 'ioc "8[.]8[.]8[.]8" | grep -q "virustotal.com/gui/ip-address/8.8.8.8"'
check "ioc: domain, any case"         b 'ioc Example.COM | grep -q "virustotal.com/gui/domain/example.com"'
check "ioc: URL links its host"       b 'ioc "hxxps://login[.]evil[.]com/a?b=1" | grep -q "virustotal.com/gui/domain/login.evil.com"'
check "ioc: CVE"                      b 'ioc cve-2024-3094 | grep -q "nvd.nist.gov/vuln/detail/CVE-2024-3094"'
check "ioc: ASN"                      b 'ioc as15169 | grep -q "bgp.he.net/AS15169"'
check "ioc: rejects what it cannot classify" b '! ioc "not an ioc" 2>/dev/null'

check "utc: report format"            b 'utc | grep -Eq "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"'
check "fromepoch: seconds"            b '[[ "$(fromepoch 0)" == "1970-01-01T00:00:00Z" ]]'
check "fromepoch: milliseconds"       b '[[ "$(fromepoch 1700000000000)" == "2023-11-14T22:13:20Z" ]]'
check "toepoch"                       b '[[ "$(toepoch 1970-01-02T00:00:00Z)" == 86400 ]]'

check "b64e and b64d"                 b '[[ "$(b64e hello)" == "aGVsbG8=" && "$(b64d aGVsbG8=)" == hello && "$(echo aGVsbG8= | b64d)" == hello ]]'
check "urle and urld"                 b '[[ "$(urle "a b&c/d")" == "a%20b%26c%2Fd" && "$(urld "a%20b+c%26")" == "a b c&" ]]'
check "rot13"                         b '[[ "$(rot13 Hello)" == Uryyb ]]'

if command -v zip >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1; then
  check "malzip and malunzip round trip" b 'printf evil >s.bin && malzip s.bin >/dev/null && rm s.bin && malunzip s.bin.zip && [[ "$(cat s.bin)" == evil ]]'
  check "malzip: wrong password fails"   b '! unzip -q -P wrong -p s.bin.zip'
else
  echo "skip  malzip (zip or unzip is not installed)"
fi

if (( fails )); then echo; echo "$fails check(s) failed"; exit 1; fi
echo; echo "all checks passed ($os)"
