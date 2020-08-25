#!/usr/bin/env bash
# shellcheck shell=bash
set -e

PROGNAME="$(basename "$0")"

CONFIG_DIR="${HOME}/.config/termchan-cli"
CONFIG_FILE="${CONFIG_DIR}/settings.sh"

TERMCHAN_SERVER=""
TERMCHAN_PORT=""
TERMCHAN_NAME=""

TERMCHAN_WRITE_CONFIG="1"
TERMCHAN_SERVER_IN_FILE="0"
TERMCHAN_PORT_IN_FILE="0"
TERMCHAN_NAME_IN_FILE="0"

# Temporary file for writing posts
TERMCHAN_POST_TEMPFILE=""

### UTILITY ####################################################################

url_base() {
	echo "http://${TERMCHAN_SERVER}:${TERMCHAN_PORT}"
}

warn() {
	echo "$1" >&2
}

### CONFIGURATION ##############################################################

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
	local file_created="1"
	if [[ $TERMCHAN_WRITE_CONFIG -eq 0 ]]; then
		return 0
	fi

	if [[ $TERMCHAN_SERVER_IN_FILE -eq 1 && \
		$TERMCHAN_PORT_IN_FILE -eq 1 && \
		$TERMCHAN_NAME_IN_FILE -eq 1 ]]; then
		return 0
	fi

	if yes_or_no "Write config?"; then
		mkdir -p "${CONFIG_DIR}"
		if [[ -f $CONFIG_FILE ]]; then
			file_created="0"
		fi
		if [[ $TERMCHAN_SERVER_IN_FILE -eq 0 ]]; then
			echo "server=${TERMCHAN_SERVER}" >>"$CONFIG_FILE"
		fi
		if [[ $TERMCHAN_PORT_IN_FILE -eq 0 ]]; then
			echo "port=${TERMCHAN_PORT}" >>"$CONFIG_FILE"
		fi
		if [[ $TERMCHAN_NAME_IN_FILE -eq 0 ]]; then
			echo "name=${TERMCHAN_NAME}" >>"$CONFIG_FILE"
		fi

		if [[ $file_created -eq 1 ]]; then
			echo "config file ${CONFIG_FILE} created"
		fi
	fi
}

### TEMP FILE (EDIT POST) ######################################################

create_tempfile() {
	TERMCHAN_POST_TEMPFILE="$(mktemp)"
}

cleanup_tempfile() {
	if [[ -f $TERMCHAN_POST_TEMPFILE ]]; then
		rm "${TERMCHAN_POST_TEMPFILE}"
	fi
}

trap cleanup_tempfile EXIT

write_post() {
	(
		echo -n "# Write your post below. Empty posts will not be uploaded."
		echo " Do not edit or remove this line."
	) >>"${TERMCHAN_POST_TEMPFILE}"
	${EDITOR:-vim} "${TERMCHAN_POST_TEMPFILE}"
	# Delete the first line
	sed -i -e "1d" "${TERMCHAN_POST_TEMPFILE}"
}

tempfile_is_nonempty() {
	[[ -f $TERMCHAN_POST_TEMPFILE ]] || return 1
	grep -E '[^\w]' "${TERMCHAN_POST_TEMPFILE}" >/dev/null
	return $?
}

### COMMANDS ###################################################################

do_welcome() {
	curl -s "$(url_base)/"
}

do_view() {
	local fragment="$1"
	fragment="${fragment##/}" # Remove leading slashes
	if [[ ! $fragment =~ [a-z]+(/[0-9]+)? ]]; then
		warn "cannot view '${fragment}', argument must be a board or a thread"
	fi
	curl -s "$(url_base)/${fragment}"
}

fail_empty_post() {
	warn "aborted: empty post was not uploaded"
	exit 3
}

do_reply() {
	local fragment="$1"
	fragment="${fragment##/}" # Remove leading slashes
	if [[ ! $fragment =~ [a-z]+/[0-9]+ ]]; then
		warn "cannot reply to '${fragment}'; must be of the form 'board/thread'"
		exit 2
	fi
	create_tempfile
	write_post
	tempfile_is_nonempty || fail_empty_post
	curl -s "$(url_base)/${fragment}" \
		--data-urlencode "name=${TERMCHAN_NAME}" \
		--data-urlencode "content@${TERMCHAN_POST_TEMPFILE}"
}

do_create_thread() {
	local board="$1"
	board="${board##/}" # Remove leading slashes
	if [[ ! $board =~ [a-z]+/? ]]; then
		warn "illegal board name: '${board}'"
		exit 2
	fi
	local topic=""
	echo "Topic for the thread? (Can be empty)"
	read -r topic
	create_tempfile
	write_post
	tempfile_is_nonempty || fail_empty_post
	curl -s "$(url_base)/${board}" \
		--data-urlencode "name=${TERMCHAN_NAME}" \
		--data-urlencode "topic=${topic}" \
		--data-urlencode "content@${TERMCHAN_POST_TEMPFILE}"
}

print_usage() {
	echo "Usage: ${PROGNAME} command [arg]"
	echo ""
	echo "Available commands:"
	echo " h|help                    print this help message"
	echo " w|welcome                 print the server's welcome message"
	echo " v|view      <board[/id]>  view a board or a thread"
	echo " r|reply     <board/id>    reply to a thread (interactive)"
	echo " c|create    <board>       create a new thread (interactive)"
}

###  MAIN ######################################################################

if [[ $# -lt 1 ]]; then
	print_usage
	exit 1
fi

read_config
prompt_for_settings
write_config

case "$1" in
h | help | -h | --help)
	print_usage
	;;
w | welcome)
	do_welcome
	;;
v | view)
	do_view "$2"
	;;
r | reply)
	do_reply "$2"
	;;
c | create-thread)
	do_create_thread "$2"
	;;
*)
	print_usage
	exit 1
	;;
esac
