#! /bin/bash

set -o errexit  # abort on nonzero exitstatus
set -o nounset  # abort on unbound variable
set -o pipefail # don't hide errors within pipes
# set -o xtrace   # display expanded commands and arguments

# Defaults
JETPACK_L4T_GIT_URI=https://github.com/cmagina/jetpack-l4t.git
USER_BIN_PATH="${HOME}/.local/bin"
USER_DATA_PATH="${HOME}/.local/share"

function usage() {
    printf "%s [options] [-i | -u]\n" $0
    printf "\t-i        - install jetpack-l4t\n"
    printf "\t-u        - uninstall jetpack-l4t\n"
    printf "\t-v        - verbose\n"
}

function install_files() {
    if [[ -d "${USER_DATA_PATH}/jetpack-l4t" ]]; then
        printf "Updating jetpack-l4t at %s/jetpack-l4t ...\n" "${USER_DATA_PATH}"
        cd "${USER_DATA_PATH}/jetpack-l4t" && git pull ${VERBOSE:-} origin main
    else
        printf "Downloading jetpack-l4t to %s/jetpack-l4t ...\n" "${USER_DATA_PATH}"
        git clone ${VERBOSE:-} "${JETPACK_L4T_GIT_URI}" "${USER_DATA_PATH}/jetpack-l4t"
    fi

    printf "Installing the jetpack-l4t.sh run script as %s/jetpack-l4t ...\n" "${USER_BIN_PATH}"
    chmod 0755 "${USER_DATA_PATH}/jetpack-l4t/jetpack-l4t.sh"
    ln ${VERBOSE:-} --symbolic "${USER_DATA_PATH}/jetpack-l4t/jetpack-l4t.sh" "${USER_BIN_PATH}/jetpack-l4t"
}

function uninstall_files() {
    if command -v jetpack-l4t; then
        declare -a jetpack_l4t_images=($(jetpack-l4t -c list))
        if [[ -n "${jetpack_l4t_images:-}" ]]; then
            printf "Found installed jetpack-l4t images:\n"
            printf "\t%s\n" ${jetpack_l4t_images[@]}
            read -p "Do you want to remove these images as part of the uninstall? (y|n) " ans
            case $ans in
            y | Y)
                for img in ${jetpack_l4t_images[@]}; do
                    jetpack-l4t -c remove -f $img
                done
                ;;
            n | N)
                printf "Not removing the jetpack-l4t images.\n"
                ;;
            esac
        fi
    fi

    printf "Removing the %s/jetpack-l4t run script ...\n" "${USER_BIN_PATH}"
    rm ${VERBOSE:-} --force "${USER_BIN_PATH}/jetpack-l4t"

    printf "Removing the %s/jetpack-l4t download ...\n" "${USER_DATA_PATH}"
    rm ${VERBOSE:-} --force --recursive "${USER_DATA_PATH}/jetpack-l4t"
}

##
## MAIN
##

if [[ $# -le 0 ]]; then
    usage
    exit
fi

while getopts ":iuvh" opt; do
    case "${opt}" in
    i)
        printf "Installing jetpack-l4t ...\n"
        COMMAND=install_files
        ;;
    u)
        printf "Uninstalling jetpack-l4t ...\n"
        COMMAND=uninstall_files
        ;;
    v)
        VERBOSE="--verbose"

        ;;
    h)
        usage
        exit
        ;;
    esac
done
shift $((OPTIND - 1))

if [[ -n "${COMMAND:-}" ]]; then
    ${COMMAND}
    exit $?
fi

usage
