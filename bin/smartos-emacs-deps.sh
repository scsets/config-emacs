#!/bin/sh
# smartos-emacs-deps.sh --- Install host tools SCS Emacs expects on SmartOS.
#
# Filename: smartos-emacs-deps.sh
# Description: One-shot deps for a new SmartOS (or illumos) Emacs host
# Author: SCS
# Copyright: Copyright (C) 2026, SCS, all rights reserved.
#
# Run as root (or a user that can write the tools prefix and gem bin dir).
# Idempotent: skips steps when tools are already present.
#
# What this installs / checks:
#   - PATH preference is handled in early-init.el (/opt/tools before /usr/bin)
#   - Core GNU helpers used by package builds and Dired:
#       gsed gmake gawk gfind ggrep gls
#     (usually already in /opt/tools from pkgsrc/tools; we only verify)
#   - rd2 from Ruby gem rdtool — needed only to build howm HTML docs
#     (howm el-get recipe in init.el checks for rd2 at install time)
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

need_gnu="gsed gmake gawk gfind ggrep gls"
missing=
for t in $need_gnu; do
  if command -v "$t" >/dev/null 2>&1; then
    msg "OK  $t -> $(command -v "$t")"
  else
    msg "MISSING  $t"
    missing="$missing $t"
  fi
done

if [ -n "$missing" ]; then
  err "core GNU tools missing:$missing"
  err "Install your usual /opt/tools (or pkgsrc) GNU coreutils/sed/make/awk/findutils/grep."
  err "This script does not guess pkgin package names for every image."
  exit 1
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
msg "Note: early-init still refuses to start without gsed/gmake/gawk/gfind/ggrep/gls."
msg "howm install will refuse without rd2 (docs); run el-get install howm after this."
exit 0
