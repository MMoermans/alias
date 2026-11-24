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

Checks the line endings, that bash and zsh can source the file quietly, that every alias points at a command
that exists, and that `sha`, `untar`, `getpass` and `ipi` really work. CI runs it on Ubuntu and macOS.
