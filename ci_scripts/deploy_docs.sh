#!/usr/bin/env bash
# Copyright © 2025 Ping Identity Corporation

#
# Ping Identity DevOps - CI scripts
#
# This script parses Dockerfiles and hooks to create docs
#
test "${VERBOSE}" = "true" && set -x

if test -z "${CI_COMMIT_REF_NAME}"; then
    CI_PROJECT_DIR="$(
        cd "$(dirname "${0}")/.." || exit 97
        pwd
    )"
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 97
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR:-.}/ci_scripts"
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

rm -rf /tmp/docker-images
TOOL_NAME="$(basename "${0}")"
OUTPUT_DIR=/tmp
DOCKER_BUILD_DIR="$(
    cd "$(dirname "${0}")"/.. || exit 97
    pwd
)"

#
# Usage printing function
#
usage() {
    cat << END_USAGE
Usage: ${TOOL_NAME} {options}
    where {options} include:

    -d, --docker-image {docker-image}
        The name of the docker image to build dos for
    --dry-run
        Run without making attempts to upload to git
    -h, --help
        Display general usage information
END_USAGE
    exit 99
}

#
# Append all arguments to the end of the current markdown document file
#
append_doc() {
    echo "$*" >> "${_docFile}"
}

#
# Append a header
#
append_header() {
    append_doc ""
}

#
# Append a footer including a link to the source file
#
append_footer() {
    _srcFile="${1}"

    append_doc ""
    append_doc "---"
    test -n "${_srcFile}" && append_doc "This document is auto-generated from _[${_srcFile}](https://github.com/pingidentity/pingidentity-docker-builds/blob/master/${_srcFile})_"
    append_doc ""
    append_doc "Copyright © 2025 Ping Identity Corporation. All rights reserved."
}

#
# Start the section on environment variables
#
append_env_table_header() {
    # TODO: future if a 'from registry pingbase', automatically add this comment
    case "${dockerImage}" in
        pingaccess | pingdirectory | pingdatasync | pingfederate | pingtoolkit | pingcentral | pingintelligence | pingdelegator | pingdirectoryproxy | pingauthorize | pingauthorizepap)
            if test "${ENV_TABLE_ACTIVE}" != "true"; then
                ENV_TABLE_ACTIVE="true"

                append_doc ""
                append_doc "## Environment Variables"
                append_doc "In addition to environment variables inherited from **[pingidentity/pingbase](https://devops.pingidentity.com/docker-images/pingbase/)**,"
                append_doc "the following environment \`ENV\` variables can be used with"
                append_doc "this image."
                append_doc ""

                append_doc "| ENV Variable  | Default     | Description"
                append_doc "| ------------: | ----------- | ---------------------------------"
            fi
            ;;
        *)
            if test "${ENV_TABLE_ACTIVE}" != "true"; then
                ENV_TABLE_ACTIVE="true"

                append_doc "## Environment Variables"
                append_doc "The following environment \`ENV\` variables can be used with"
                append_doc "this image."
                append_doc ""

                append_doc "| ENV Variable  | Default     | Description"
                append_doc "| ------------: | ----------- | ---------------------------------"
            fi
            ;;
    esac
}

#
# Append an environment variable, default value and description
#
append_env_variable() {
    envVar="${1}" && shift
    envDesc="${1}" && shift
    envDef="${1}" && shift

    append_doc "| ${envVar}  | ${envDef}  | ${envDesc} |"
}

#
# append docs for exposed ports
#
append_expose_ports() {
    exposePorts="${1}"

    append_doc "## Ports Exposed"
    append_doc ""
    append_doc "The following ports are exposed from the container.  If a variable is"
    append_doc "used, then it may come from a parent container"
    append_doc ""

    for port in ${exposePorts}; do
        append_doc "- $port"
    done

    append_doc ""
}

append_page_meta_title() {
    title=${1}
    append_doc "---"
    append_doc "title: $title"
    append_doc "---"
}

#
# parse all the hooks in a product's /opt/staging/hooks
#
parse_hooks() {
    _dockerImage="${1}"
    _hooksDir="${DOCKER_BUILD_DIR}/${_dockerImage}/opt/staging/hooks"

    mkdir -p "${OUTPUT_DIR}/docker-images/${_dockerImage}/hooks"

    banner "Parsing hooks for ${_dockerImage}..."

    _hookFiles=""

    #
    # The following creates a set of .../product/hooks/{hook-name}.md file for each hook
    # pulling in docs in that hook file.
    #
    for _hookFilePath in "${_hooksDir}"/*; do
        test -f "${_hookFilePath}" || continue
        _hookFile=$(basename "${_hookFilePath}")
        _hookFiles="${_hookFiles:+${_hookFiles} }${_hookFile}"
        _docFile="${OUTPUT_DIR}/docker-images/${_dockerImage}/hooks/${_hookFile}.md"
        rm -f "${_docFile}"
        echo "  parsing hook ${_hookFile}"
        append_page_meta_title "Ping Identity DevOps \`${_dockerImage}\` Hook - \`${_hookFile}\`"
        append_header
        append_doc "# Ping Identity DevOps \`${_dockerImage}\` Hook - \`${_hookFile}\`"
        awk '$0~/^#-/ && $0!~/^#-$/ {gsub(/^#-/,"");print;}' "${_hookFilePath}" >> "${_docFile}"

        append_footer "${_dockerImage}/opt/staging/hooks/${_hookFile}"
    done

    #
    # The following creates a set of .../product/hooks/README.md file as a table of
    # contents for all the hooks for that product.
    #
    # If there are no hooks for that product, then a message will be provided
    # to that effect.
    #
    _docFile="${OUTPUT_DIR}/docker-images/${_dockerImage}/hooks/README.md"
    rm -f "${_docFile}"
    append_header
    append_doc "# Ping Identity DevOps \`${_dockerImage}\` Hooks"

    if test -z "${_hookFiles}"; then
        append_doc "There are no default hooks defined for the \`${_dockerImage}\` image."
        append_doc ""
        append_doc "Hooks defined by parent images (i.e. pingcommon/pingdatacommon)"
        append_doc "will be inherited by this image."
        append_footer ""
    else
        append_doc "List of available hooks:"
        for _hookFile in ${_hookFiles}; do
            append_doc "* [${_hookFile}](${_hookFile}.md)"
        done
        append_doc ""
        append_doc "These hooks will replace hooks defined by parent images (i.e. pingcommon/pingdatacommon)"
        append_footer "${_dockerImage}/opt/staging/hooks"
    fi
}

#
# parse the dockerfile for product
#
parse_dockerfile() {
    _dockerImage="${1}"
    _dockerFile="${DOCKER_BUILD_DIR}/${_dockerImage}/Dockerfile"

    mkdir -p "${OUTPUT_DIR}/docker-images/${_dockerImage}"

    _docFile="${OUTPUT_DIR}/docker-images/${_dockerImage}/README.md"
    rm -f "${_docFile}"

    echo "Parsing Dockerfile ${_dockerImage}..."

    append_page_meta_title "Ping Identity DevOps Docker Image - \`${_dockerImage}\`"
    append_header

    # Use a flag to determine whether the next environment variable should be documented.
    _skipNextDoc=""

    while read -r line; do
        #
        # Parse the ENV Description
        #   Example: #-- This is the description
        #
        # Each line starting with #-- will be concatenated onto the
        # description until an ENV variable line is found
        #
        if [ "$(echo "${line}" | cut -c-3)" = "#--" ]; then
            ENV_DESCRIPTION="${ENV_DESCRIPTION}$(echo "${line}" | cut -c5-) "
            continue
        fi

        # A hash followed by two forward slashes indicates that the next uncommented line should
        # not be documented.
        if [ "$(echo "${line}" | cut -c-3)" = "#//" ]; then
            _skipNextDoc="true"
            continue
        fi

        #
        # Parse the ENV variable name and value
        #   Example: ENV VARIABLE_ONE=value1 \
        #                VARIABLE_TWO=value2
        #
        # Also supports line continuations with \, so multiple ENV vars can be set in one command
        # Typically ENV lines should use continuations rather than separate ENV statements, to
        # reduce layers in our images, though ENV variables dependent on other variables will need
        # to be defined in separate statements.
        #
        # This logic is unable to handle when the variables values themselves are split onto multiple
        # lines, since it can only check for the \ at the end of the line, so variable values should
        # be kept to a single line to ensure the documentation is valid.
        #
        # Ignore this line if _skipNextDoc is true.
        if [ -n "$_skipNextDoc" ]; then
            _skipNextDoc=""
            continue
        fi
        if [ "$(echo "${line}" | cut -c-4)" = "ENV " ] ||
            [ "$(echo "${line}" | cut -c-12)" = "ONBUILD ENV " ] ||
            [ "${_envContinuation}" = "true" ] && [ "${line}" ] && [ ! "$(echo "${line}" | cut -c-1)" = "#" ]; then
            # Read the variable name before the '='
            if [ "${_envContinuation}" = "true" ]; then
                # Don't expect "ENV" or "ONBUILD ENV"
                ENV_VARIABLE=$(echo "${line}" | sed -e 's/=/x=x/' -e 's/^\(.*\)x=x.*/\1/')
            else
                # Expect "ENV" or "ONBUILD ENV"
                ENV_VARIABLE=$(echo "${line}" | sed -e 's/=/x=x/' -e 's/^.*ENV[[:space:]]\(.*\)x=x.*/\1/')
            fi

            # Read the variable value after the '=', and trim off the ' \' at the end if present
            ENV_VALUE=$(echo "${line}" | sed -e 's/=/x=x/' -e 's/^.*x=x\(.*\)/\1/' -e 's/[[:space:]]\{1,\}\\$//' -e 's/^"\(.*\)"$/\1/')

            # If ENV line ends in slash, the next command will also be an ENV var
            # This isn't able to handle when the variable values themselves are multiline.
            # It assumes that any line continuation is the end of the previous variable.
            if echo "${line}" | grep -q "[[:space:]]\\\\$" > /dev/null 2>&1; then
                _envContinuation="true"
            else
                _envContinuation="false"
            fi

            append_env_table_header

            append_env_variable "${ENV_VARIABLE}" "${ENV_DESCRIPTION}" "${ENV_VALUE}"
            ENV_DESCRIPTION=""

            continue
        fi

        #
        # Parse the EXPOSE values
        #   Example: EXPOSE PORT1 PORT2
        #
        if [ "$(echo "${line}" | cut -c-7)" = "EXPOSE " ] ||
            [ "$(echo "${line}" | cut -c-15)" = "ONBUILD EXPOSE " ]; then
            # shellcheck disable=SC2001
            EXPOSE_PORTS=$(echo "${line}" | sed 's/^.*EXPOSE \(.*\)$/\1/')

            # Add an empty line after the ENV table
            if [ "${ENV_TABLE_ACTIVE}" = "true" ]; then
                append_header
                ENV_TABLE_ACTIVE="false"
            fi
            append_expose_ports "${EXPOSE_PORTS}"

            continue
        fi

        #
        # Parse the remaining lines for "#-"
        #
        # Lines starting with '#-' (only one dash) will be added to the doc page outside of the ENV table
        #
        if [ "$(echo "${line}" | cut -c-2)" = "#-" ]; then
            # Add an empty line after the ENV table
            if [ "${ENV_TABLE_ACTIVE}" = "true" ]; then
                append_header
                ENV_TABLE_ACTIVE="false"
            fi

            md=$(echo "$line" | sed \
                -e 's/^\#- //' \
                -e 's/^\#-$//')

            append_doc "$md"
        fi
    done < "${_dockerFile}"

    append_header
    append_doc "## Docker Container Hook Scripts"
    append_doc ""
    append_doc "Please go [here](https://github.com/pingidentity/pingidentity-devops-getting-started/tree/master/docs/docker-images/${_dockerImage}/hooks/README.md) for details on all ${_dockerImage} hook scripts"
    append_footer "${_dockerImage}/Dockerfile"
}

#
# main
#
dockerImages="pingaccess pingfederate pingdirectory pingdatasync
pingbase pingcommon pingdatacommon
pingdataconsole ldap-sdk-tools pingtoolkit
pingdirectoryproxy pingdelegator apache-jmeter pingcentral pingintelligence pingauthorize pingauthorizepap"
#
# Parse the provided arguments, if any
#
while test -n "${1}"; do
    case "${1}" in
        -d | --docker-image)
            shift
            if test -z "${1}"; then
                echo "You must provide name of docker-image(s)"
                usage
            fi
            dockerImages="${1}"
            ;;
        --dry-run)
            dryRun="echo"
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unrecognized option"
            usage
            ;;
    esac
    shift
done

for dockerImage in ${dockerImages}; do
    echo "Creating docs for '${dockerImage}'"

    test ! -d "${DOCKER_BUILD_DIR}/${dockerImage}" &&
        echo "Docker Image '${dockerImage}' not found"

    parse_dockerfile "${dockerImage}"
    parse_hooks "${dockerImage}"
done

set -x
cd /tmp || exit 97
rm -rf pingidentity-devops-getting-started
${dryRun} git clone "https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/pingidentity/pingidentity-devops-getting-started.git"
${dryRun} cp -r docker-images pingidentity-devops-getting-started/docs
${dryRun} cd pingidentity-devops-getting-started || exit 97
${dryRun} git config user.email "devops_program@pingidentity.com"
${dryRun} git config user.name "devops_program"
${dryRun} git add .
${dryRun} git commit -m "updated from docker-builds"
${dryRun} git push origin master
exit 0
