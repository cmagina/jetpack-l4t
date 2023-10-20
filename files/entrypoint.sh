#! /bin/bash

set -o errexit  # abort on nonzero exitstatus
set -o nounset  # abort on unbound variable
set -o pipefail # don't hide errors within pipes
# set -o xtrace   # display expanded commands and arguments

DEFAULT_ROOTDEV=external

function usage() {
    printf "%s [options] -c <command>\n" $0
    printf "Uses the boardctl tool to perform the power commands.\n"
    printf "If no command is passed in, the script will drop to the shell.\n"
    printf "Required:\n"
    printf "\t-c <command>                      - command to run\n"
    printf "Commands:\n"
    printf "\tflash                             - flashes the board using the firmware built into the container\n"
    printf "\tmanifest                          - print the build manifest\n"
    printf "\tshell                             - drop into a shell\n"
    printf "Board Control Commands:\n"
    printf "\tpower_on                          - Uses boardctl to power on the board\n"
    printf "\tpower_off                         - Uses boardctl to power off the board\n"
    printf "\trecovery                          - Uses boardctl to put the board into recovery mode\n"
    printf "\treset                             - Uses boardctl to reset the board\n"
    printf "\tstatus                            - Uses boardctl to get the power status of the board\n"
    printf "Flash Options:\n"
    printf "\t-b <jetpack board config>         - jetpack board config to flash\n"
    printf "\t-d <rootdev>                      - root device to flash (default %s)\n" ${DEFAULT_ROOTDEV}
    printf "Boardctl Options:\n"
    printf "\t-t <target board>                 - boardctl target board (required)\n"
}

function boardctl() {
    local boardctl_command=$1
    local target_board=$2

    ./tools/board_automation/boardctl -t ${target_board} ${boardctl_command}
}

function flash() {
    printf "Flashing the board ...\n"
    sudo ./flash.sh ${JETPACK_BOARD_CONFIG} ${ROOTDEV:-${DEFAULT_ROOTDEV}}
}

while getopts ":vhb:c:d:t:" opt; do
    case "${opt}" in
    b)
        JETPACK_BOARD_CONFIG=${OPTARG}
        ;;
    c)
        COMMAND=${OPTARG}
        ;;
    d)
        ROOTDEV=${OPTARG}
        ;;
    t)
        TARGET_BOARD=${OPTARG}
        ;;
    v)
        set -o xtrace
        ;;
    h)
        usage
        exit
        ;;
    esac
done
shift $((OPTIND - 1))

pushd ${WORKDIR}/Linux_for_Tegra &>/dev/null
case ${COMMAND:-} in
flash)
    flash
    exit $?
    ;;
manifest)
    cat ${WORKDIR}/build.manifest
    exit $?
    ;;
power_on | power_off | recovery | reset | status)
    printf "Running the boardctl %s command ...\n" ${COMMAND}
    if [[ -z "${TARGET_BOARD:-}" ]]; then
        printf "Need to specify a target board\n"
        ./tools/board_automation/boardctl ${COMMAND}
        exit $?
    fi

    boardctl ${COMMAND} ${TARGET_BOARD}
    exit $?
    ;;
shell)
    /bin/bash
    exit $?
    ;;
esac
popd &>/dev/null

/bin/bash
