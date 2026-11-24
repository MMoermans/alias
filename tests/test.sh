#!/usr/bin/env bash
# shellcheck disable=SC2016  # single-quoted snippets are code for a second shell, nothing may expand here
# Sources aliases.sh in bash (and zsh, when installed) and checks that it behaves.
# Run on Linux or macOS:  bash tests/test.sh
set -u
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
file="$here/aliases.sh"
os="$(uname -s)"
fails=0

check() { # check <description> <command...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "ok    $desc"; else echo "FAIL  $desc"; fails=$((fails + 1)); fi
}

# --- the file itself ---------------------------------------------------------------------
check "no carriage returns (they break every alias)" bash -c "! grep -q \$'\\r' '$file'"
check "bash can parse it"                           bash -n "$file"

# --- sourcing, in each shell --------------------------------------------------------------
want="c .. ... cp mv ln untar sha getpass ports update"
[[ "$os" == Linux ]] && want="$want ipt"
[[ "$os" == Darwin ]] && ! command -v brew >/dev/null 2>&1 && want="${want/update/}"

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
b() { bash -c "shopt -s expand_aliases${nl}. '$file'${nl}$1"; }

printf 'abc' >data.txt
check "sha: SHA-256 of 'abc'"  b '[[ "$(sha data.txt)" == ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad* ]]'

mkdir t && echo hello >t/f
tar -czf a.tgz t && tar -cJf a.txz t && rm -rf t
check "untar: .tar.gz"         b 'mkdir x1 && cd x1 && untar ../a.tgz && [[ -f t/f ]]'
check "untar: .tar.xz"         b 'mkdir x2 && cd x2 && untar ../a.txz && [[ -f t/f ]]'

check "getpass: 28 characters" b '[[ $(getpass | tr -d "\n" | wc -c) -eq 28 ]]'
check "ipi: prints an IPv4 address" b 'ipi | grep -Eq "^[0-9]+(\.[0-9]+){3}$"'

if (( fails )); then echo; echo "$fails check(s) failed"; exit 1; fi
echo; echo "all checks passed ($os)"
