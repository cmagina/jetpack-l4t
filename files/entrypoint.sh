#! /bin/bash

set -o errexit  # abort on nonzero exitstatus
set -o nounset  # abort on unbound variable
set -o pipefail # don't hide errors within pipes
# set -o xtrace   # display expanded commands and arguments

DEFAULT_JETSON_ROOTDEV=external
DEFAULT_JETSON_TARGET_BOARD=concord

function usage() {
    printf "%s [options] -c <command>\n" $0
    printf "Uses the boardctl tool to perform the power commands.\n"
    printf "If no command is passed in, the script will drop to the shell.\n"
    printf "Required:\n"
    printf "\t-c <command>                      - command to run\n"
    printf "Options:\n"
    printf "\t-b <jetson board config>          - jetson board config to flash\n"
    printf "\t-d <rootdev>                      - root device to flash (default %s)\n" ${DEFAULT_JETSON_ROOTDEV}
    printf "\t-t <jetson target board>          - boardctl target board (default %s)\n" ${DEFAULT_JETSON_TARGET_BOARD}
    printf "Commands:\n"
    printf "\tflash                             - flashes the jetson using the firmware built into the container\n"
    printf "\tmanifest                          - print the build manifest\n"
    printf "\tpower_on                          - Uses boardctl to power on the jetson\n"
    printf "\tpower_off                         - Uses boardctl to power off the jetson\n"
    printf "\trecovery                          - Uses boardctl to put the jetson into recovery mode\n"
    printf "\treset                             - Uses boardctl to reset the jetson\n"
    printf "\tstatus                            - Uses boardctl to get the power status of the jetson\n"
}

function boardctl() {
    ./tools/board_automation/boardctl -t ${JETSON_TARGET_BOARD:-${DEFAULT_JETSON_TARGET_BOARD}} $1
}

function flash() {
    printf "Flashing the jetson ...\n"
    sudo ./flash.sh ${JETSON_BOARD_CONFIG} ${JETSON_ROOTDEV:-${DEFAULT_JETSON_ROOTDEV}}
}

while getopts ":vhb:c:d:t:" opt; do
    case "${opt}" in
    b)
        JETSON_BOARD_CONFIG=${OPTARG}
        ;;
    c)
        COMMAND=${OPTARG}
        ;;
    d)
        JETSON_ROOTDEV=${OPTARG}
        ;;
    t)
        JETSON_TARGET_BOARD=${OPTARG}
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
    boardctl ${COMMAND}
    exit $?
    ;;
esac
popd &>/dev/null

/bin/bash
