#!/usr/bin/env bash
# Turn niri's own keybinds off so a shortcut trainer can see the keys.
#
# niri can be told to load any config file at runtime, so practice mode is a
# config swap and nothing else: `practice.kdl` is this flake's config with the
# binds section replaced by a single bind that swaps back. No file is edited,
# nothing home-manager owns is touched, and a rebuild cannot collide with it.
set -euo pipefail

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
state="${XDG_RUNTIME_DIR:-/tmp}/niri-practice-mode"

on() {
	niri msg action load-config-file --path "$config_dir/practice.kdl"
	: >"$state"
}

off() {
	niri msg action load-config-file --path "$config_dir/config.kdl"
	rm -f "$state"
}

case "${1:-toggle}" in
toggle)
	if [ -e "$state" ]; then off; else on; fi
	;;
on) on ;;
off) off ;;
run)
	shift
	[ $# -gt 0 ] || {
		echo "practice-mode run: nothing to run" >&2
		exit 2
	}
	on
	# Binds come back however the command exits — crash, kill, or normal quit.
	trap off EXIT INT TERM
	"$@"
	;;
*)
	echo "usage: practice-mode [toggle|on|off|run COMMAND...]" >&2
	exit 2
	;;
esac
