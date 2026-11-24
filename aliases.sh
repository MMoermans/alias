# shellcheck shell=bash
# Shell aliases for bash and zsh, for Linux (Debian, Arch/CachyOS, ...) and macOS.
#
#   source /path/to/aliases.sh        # add this line to ~/.bashrc or ~/.zshrc
#
# Aliases are only defined when the command they need exists, so sourcing this file
# on any machine is safe and prints nothing.

# --- Safety: ask before overwriting ----------------------------------------------------
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'

# --- Navigation ------------------------------------------------------------------------
alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'

# --- Files, archives and hashes ----------------------------------------------------------
# tar detects the compression itself: .tar, .tar.gz, .tar.bz2, .tar.xz, .tar.zst
alias untar='tar -xvf'

# SHA-256 of a file: sha file.iso
if command -v sha256sum >/dev/null 2>&1; then
  alias sha='sha256sum'
elif command -v shasum >/dev/null 2>&1; then
  alias sha='shasum -a 256'
fi

# Random 28 character password
alias getpass='openssl rand -base64 20'

# --- Network ---------------------------------------------------------------------------
# Public IP address. Asks ipinfo.io, so that service sees the request.
ipe() { curl -fsS https://ipinfo.io/ip; echo; }

# Local IP address of the interface that has the default route
ipi() {
  case "$(uname -s)" in
    Darwin) ipconfig getifaddr "$(route -n get default 2>/dev/null | awk '/interface:/ { print $2 }')" ;;
    *)      ip route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit } }' ;;
  esac
}

case "$(uname -s)" in
  Darwin)
    # Listening TCP ports and the programs behind them
    alias ports='lsof -iTCP -sTCP:LISTEN -n -P'
    ;;
  Linux)
    # Listening TCP and UDP ports. Run with sudo to see programs of other users
    alias ports='ss -tulpn'
    # Firewall rules with packet counters and rule numbers
    alias ipt='sudo iptables -L -n -v --line-numbers'
    ;;
esac

# --- Updates: pick the package manager that exists ---------------------------------------
if command -v apt-get >/dev/null 2>&1; then
  alias update='sudo apt-get update && sudo apt-get upgrade'
elif command -v pacman >/dev/null 2>&1; then
  alias update='sudo pacman -Syu'
elif command -v brew >/dev/null 2>&1; then
  alias update='brew update && brew upgrade'
fi
