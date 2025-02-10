#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

#
# Ping Identity DevOps - Docker Build Hooks
#
#- This hook is called when the container has been built in a prior startup
#- and a configuration has been found.
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=./pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

echo "Restarting container"

run_hook "21-update-server-profile.sh"
