#!/bin/sh
# smartos-emacs-deps.sh --- Install host tools SCS Emacs expects on SmartOS.
#
# Filename: smartos-emacs-deps.sh
# Description: One-shot deps for a new SmartOS (or illumos) Emacs host
# Author: SCS
# Copyright: Copyright (C) 2026, SCS, all rights reserved.
# Created: 2026-08-03 Mon 16:34
# Version: 0.1.1
# Last-Updated: 2026-08-31 Mon 12:52
# Update #: 1
#
# Run as root (or a user that can write the tools prefix and gem bin dir).
# Idempotent: skips steps when tools are already present; pkgin-installs
# missing GNU packages; gem-installs rdtool when rd2 is missing.
#
# What this installs / checks:
#   - PATH preference is handled in early-init.el (/opt/tools before /usr/bin)
#   - Core GNU helpers used by package builds and Dired.  Probe -> pkgin:
#       gsed  -> gsed
#       gmake -> gmake
#       gawk  -> gawk
#       gfind -> findutils
#       grep  -> grep     (GNU grep; binary is grep, also ships ggrep)
#       gls   -> coreutils
#     Keep this table in sync with scs/smartos-gnu-tool-packages.
#   - rd2 from Ruby gem rdtool -- needed only to build howm HTML docs
#     (howm el-get recipe in init.el also tries gem install at howm build)
#
# Usage:
#   ./bin/smartos-emacs-deps.sh
#   sh /path/to/config-emacs/bin/smartos-emacs-deps.sh
#
set -eu

msg() { printf '%s\n' "$*"; }
err() { printf 'smartos-emacs-deps: %s\n' "$*" >&2; }

# Prefer the same prefixes early-init prepends.
PATH="/opt/tools/bin:/opt/tools/sbin:/opt/local/bin:/opt/local/sbin:${PATH:-/usr/bin:/bin}"
export PATH

case $(uname -s) in
  SunOS) ;;
  *)
    err "this script is for SmartOS/illumos (uname -s was $(uname -s))"
    err "on other hosts install gsed/gmake/... and: gem install rdtool"
    exit 1
    ;;
esac

# Return 0 when NAME is GNU grep under a tools prefix, not illumos /usr/bin/grep.
gnu_grep_ok()
{
  if command -v ggrep >/dev/null 2>&1; then
    case $(command -v ggrep) in
      /opt/tools/*|/opt/local/*|/usr/local/*) return 0 ;;
    esac
  fi
  if command -v grep >/dev/null 2>&1; then
    case $(command -v grep) in
      /opt/tools/*|/opt/local/*|/usr/local/*) return 0 ;;
    esac
  fi
  return 1
}

# Print the path used to satisfy a probe name.
tool_path()
{
  bin=$1
  if [ "$bin" = grep ]; then
    if command -v ggrep >/dev/null 2>&1; then
      case $(command -v ggrep) in
        /opt/tools/*|/opt/local/*|/usr/local/*)
          command -v ggrep
          return 0
          ;;
      esac
    fi
    command -v grep
    return 0
  fi
  command -v "$bin"
}

# Return 0 when the probe binary is present (GNU grep is special).
tool_ok()
{
  bin=$1
  if [ "$bin" = grep ]; then
    gnu_grep_ok
    return $?
  fi
  command -v "$bin" >/dev/null 2>&1
}

# Probe|pkgin-package.  Same data as scs/smartos-gnu-tool-packages.
# grep (not ggrep) is the pkgsrc package name on SmartOS tools.
need_pairs="gsed:gsed gmake:gmake gawk:gawk gfind:findutils grep:grep gls:coreutils"

missing_bins=
missing_pkgs=
for pair in $need_pairs; do
  bin=${pair%%:*}
  pkg=${pair#*:}
  if tool_ok "$bin"; then
    msg "OK  $bin -> $(tool_path "$bin")"
  else
    msg "MISSING  $bin (pkgin package $pkg)"
    missing_bins="$missing_bins $bin"
    # Avoid duplicate package names if two probes ever share a package.
    case " $missing_pkgs " in
      *" $pkg "*) ;;
      *) missing_pkgs="$missing_pkgs $pkg" ;;
    esac
  fi
done

if [ -n "$missing_pkgs" ]; then
  if ! command -v pkgin >/dev/null 2>&1; then
    err "pkgin not on PATH=$PATH; cannot install:$missing_pkgs"
    exit 1
  fi
  msg "Installing via: pkgin -y install$missing_pkgs"
  # shellcheck disable=SC2086
  pkgin -y install $missing_pkgs
  still=
  for pair in $need_pairs; do
    bin=${pair%%:*}
    if ! tool_ok "$bin"; then
      still="$still $bin"
    fi
  done
  if [ -n "$still" ]; then
    err "still missing after pkgin:$still"
    err "Install your usual /opt/tools GNU coreutils/sed/make/awk/findutils/grep."
    exit 1
  fi
  for pair in $need_pairs; do
    bin=${pair%%:*}
    case " $missing_bins " in
      *" $bin "*)
        msg "OK  $bin -> $(tool_path "$bin")  (installed)"
        ;;
    esac
  done
fi

if command -v rd2 >/dev/null 2>&1; then
  msg "OK  rd2 -> $(command -v rd2)"
else
  if ! command -v gem >/dev/null 2>&1; then
    err "rd2 missing and gem not on PATH; install Ruby/gem then: gem install rdtool"
    exit 1
  fi
  msg "Installing rdtool gem (provides rd2) via: gem install rdtool"
  gem install rdtool --no-document
  if ! command -v rd2 >/dev/null 2>&1; then
    err "gem install finished but rd2 still not on PATH=$PATH"
    err "ensure gem bindir is under /opt/tools/bin or add it to PATH"
    exit 1
  fi
  msg "OK  rd2 -> $(command -v rd2)"
fi

if command -v bash >/dev/null 2>&1; then
  msg "OK  bash -> $(command -v bash)  (early-init sets MAKEFLAGS SHELL=bash)"
else
  err "bash missing; early-init needs it for GNU make recipes on SmartOS"
  exit 1
fi

msg "All SCS Emacs SmartOS host deps look good."
msg "Note: early-init pkgin-installs missing gsed/gmake/gawk/gfind/grep/gls on start."
msg "howm install will refuse without rd2 (docs); run el-get install howm after this."
exit 0
