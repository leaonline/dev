#!/usr/bin/env bash
# ---------------------------------------------------------------------
# This runs the complete app-suite from one terminal command,
# where each app is invoked in a new tab of the current window
# and the current window remains open (for git commands).
# MIT LICENSE, Jan Küster 2020, info at jankuester dot com
# ---------------------------------------------------------------------

# gets the current terminal on most linux-based systems
# may not work on macos, so we will have to provide a workaround there
# see: https://unix.stackexchange.com/questions/264329/get-the-terminal-emulator-name-inside-the-shell-script

function get_terminal {
    local sid=$(ps -o sid= -p "$$")
    local sid_as_integer=$((sid)) # strips blanks if any
    local session_leader_parent=$(ps -o ppid= -p "$sid_as_integer")
    local session_leader_parent_as_integer=$((session_leader_parent))
    local emulator=$(ps -o comm= -p "$session_leader_parent_as_integer")
    echo ${emulator}
    exit 0
}

CURRENT_TERMINAL=$( get_terminal )

# runs an app in the subfolder
# in a new tab of the current window
# with respective title and environment
# see https://stackoverflow.com/a/52330776/3098783

function run_app {
    local APP_NAME=$( basename "$1" )
    local APP_PATH="$(pwd)/${1}"

    # yes this uses a variable outside of local scope
    # se we only need to get the current terminal once
    eval '${CURRENT_TERMINAL} --tab --working-directory=${APP_PATH} --title="${APP_NAME}" --command="bash ./run.sh"'
}

run_app leaonline-accounts
run_app leaonline-backend
run_app leaonline-content
