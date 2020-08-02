#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

PROGNAME="$0"

CONFIG_DIR="${HOME}/.config/termchan-cli"
CONFIG_FILE="${CONFIG_DIR}/settings.sh"

TERMCHAN_SERVER=""
TERMCHAN_PORT=""
TERMCHAN_NAME=""

TERMCHAN_WRITE_CONFIG="1"
TERMCHAN_SERVER_IN_FILE="0"
TERMCHAN_PORT_IN_FILE="0"
TERMCHAN_NAME_IN_FILE="0"

read_config() {
	# Config variables
	local server=""
	local port=""
	local name=""
	if [[ -f $CONFIG_FILE ]]; then
		# shellcheck source=/dev/null
		source "$CONFIG_FILE"
		if [[ -z $TERMCHAN_SERVER ]]; then
			TERMCHAN_SERVER="$server"
			if [[ -n $TERMCHAN_SERVER ]]; then
				TERMCHAN_SERVER_IN_FILE=1
			fi
		fi

		if [[ -z $TERMCHAN_PORT ]]; then
			TERMCHAN_PORT="$port"
			if [[ -n $TERMCHAN_PORT ]]; then
				TERMCHAN_PORT_IN_FILE=1
			fi
		fi

		if [[ -z $TERMCHAN_NAME ]]; then
			TERMCHAN_NAME="$name"
			# Empty value in file is permitted
			if grep -q -E 'name=' "${CONFIG_FILE}"; then
				TERMCHAN_NAME_IN_FILE=1
			fi
		fi
	fi
}

prompt_for_settings() {
	while [[ -z $TERMCHAN_SERVER ]]; do
		read -r -p "Termchan server (URL or IP): " TERMCHAN_SERVER
	done

	if [[ -z $TERMCHAN_PORT ]]; then
		read -r -p "Termchan server port number (default 8088): " TERMCHAN_PORT
		TERMCHAN_PORT="${TERMCHAN_PORT:-8088}"
	fi

	if [[ $TERMCHAN_NAME_IN_FILE -eq 0 && -z $TERMCHAN_NAME ]]; then
		read -r -p "Termchan user name (can be empty): " TERMCHAN_NAME
	fi
}

yes_or_no() {
	local prompt="$1"
	local yn
	read -r -p "${prompt} [y/n]: " yn
	case $yn in
	[Yy]*)
		return 0
		;;
	[Nn]*)
		return 1
		;;
	*)
		yes_or_no "${prompt}"
		;;
	esac
}

write_config() {
	if [[ $TERMCHAN_WRITE_CONFIG -eq 0 ]]; then
		return 0
	fi

	if [[ $TERMCHAN_SERVER_IN_FILE -eq 1 && $TERMCHAN_PORT_IN_FILE -eq 1 && $TERMCHAN_NAME_IN_FILE -eq 1 ]]; then
		return 0
	fi

	if yes_or_no "Write config?"; then
		mkdir -p "${CONFIG_DIR}"
		if [[ $TERMCHAN_SERVER_IN_FILE -eq 0 ]]; then
			echo "server=${TERMCHAN_SERVER}" >>"$CONFIG_FILE"
		fi
		if [[ $TERMCHAN_PORT_IN_FILE -eq 0 ]]; then
			echo "port=${TERMCHAN_PORT}" >>"$CONFIG_FILE"
		fi
		if [[ $TERMCHAN_NAME_IN_FILE -eq 0 ]]; then
			echo "name=${TERMCHAN_NAME}" >>"$CONFIG_FILE"
		fi
	fi
}

url_base() {
	echo "${TERMCHAN_SERVER}:${TERMCHAN_PORT}"
}

do_help() {
	curl -s "$(url_base)/"
}

do_view() {
	local fragment="$1"
	curl -s "$(url_base)/${fragment}"
}

print_usage() {
	echo "Usage: ${PROGNAME} (help|view)"
}

# MAIN
if [[ $# -lt 1 ]]; then
	print_usage
	exit 1
fi

read_config
prompt_for_settings
write_config

case "$1" in
"help")
	do_help
	;;
"view")
	do_view "$2"
	;;
esac