#! /bin/bash

set -o errexit  # abort on nonzero exitstatus
set -o nounset  # abort on unbound variable
set -o pipefail # don't hide errors within pipes
# set -o xtrace   # display expanded commands and arguments

JETSON_ARRAY=(
    agxorin
    igxorin
    orinnx
    orinnano
    xaviernx
)

function usage() {
    printf "%s [options] -c <command>\n" $0
    printf "Uses the boardctl tool to perform the power commands.\n"
    printf "If no command is passed in, the script will drop to the shell.\n"
    printf "Required:\n"
    printf "\t-c <command>                      - command to run\n"
    printf "Options:\n"
    printf "\t-b <jetson board config>          - jetson board config to flash\n"
    printf "\t-d <rootdev>                      - root device to flash (default %s)\n" ${DEFAULT_JETSON_ROOTDEV}
    printf "\t-j <jetson>                       - jetson to flash\n"
    printf "Commands:\n"
    printf "\tflash                             - flashes the jetson using the firmware built into the container\n"
    printf "\tpower_on                          - Uses boardctl to power on the jetson\n"
    printf "\tpower_off                         - Uses boardctl to power off the jetson\n"
    printf "\trecovery                          - Uses boardctl to put the jetson into recovery mode\n"
    printf "\treset                             - Uses boardctl to reset the jetson\n"
    printf "\tstatus                            - Uses boardctl to get the power status of the jetson\n"
}

function boardctl() {
    case ${JETSON_BOARD:-} in
    agxorin)
        JETSON_TARGET_BOARD=concord
        ;;
    *)
        printf "Unsupported board: %s\n" ${JETSON_BOARD:-Unspecified}
        exit 1
        ;;
    esac

    ./tools/board_automation/boardctl -t ${JETSON_TARGET_BOARD} $1
}

function check_for_jetson_recovery_device() {
    lsusb | grep --quiet "${JETSON_RECOVERY_DEVICE}"
    echo $?
}

function flash() {
    case ${JETSON_BOARD} in
    agxorin)
        JETSON_RECOVERY_DEVICE="ID 0955:7023 NVIDIA Corp."

        printf "Putting the jetson %s into recovery ...\n" ${JETSON_BOARD}
        boardctl recovery
        ;;
    igxorin)
        JETSON_RECOVERY_DEVICE="ID 0955:7023 NVIDIA Corp."

        printf "Put the jetson %s into recovery ...\n" ${JETSON_BOARD}
        read -p "Press Enter to continue or Ctrl+C to quit"
        ;;
    orinnx)
        JETSON_RECOVERY_DEVICE="ID 0955:7323 NVIDIA Corp."

        printf "Put the jetson %s into recovery ...\n" ${JETSON_BOARD}
        read -p "Press Enter to continue or Ctrl+C to quit"
        ;;
    orinnano)
        JETSON_RECOVERY_DEVICE="ID 0955:7523 NVIDIA Corp."

        printf "Put the jetson %s into recovery ...\n" ${JETSON_BOARD}
        read -p "Press Enter to continue or Ctrl+C to quit"
        ;;
    xaviernx)
        JETSON_RECOVERY_DEVICE="ID 0955:7e19 NVIDIA Corp."

        printf "Put the jetson %s into recovery ...\n" ${JETSON_BOARD}
        read -p "Press Enter to continue or Ctrl+C to quit"
        ;;
    *)
        printf "Unsupported jetson board: %s\n" ${JETSON_BOARD}
        exit 1
        ;;
    esac

    printf "Checking if the jetson %s is in recovery ...\n" ${JETSON_BOARD}
    STATUS=$(check_for_jetson_recovery_device)
    if [[ ${STATUS} -ne 0 ]]; then
        printf "Put the jetson %s into recovery mode ...\n" ${JETSON_BOARD}
        read -p "Press Enter to continue or Ctrl+C to quit"

        STATUS=$(check_for_jetson_recovery_device)
        if [[ ${STATUS} -ne 0 ]]; then
            printf "Jetson recovery mode device (%s) not found, exiting.\n" "${JETSON_RECOVERY_DEVICE}"
            exit 1
        fi
    fi

    printf "Flashing the jetson ...\n"
    sudo ./flash.sh ${JETSON_BOARD_CONFIG} ${JETSON_ROOTDEV}
}

while getopts ":vhb:c:d:j:" opt; do
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
    j)
        JETSON_BOARD=${OPTARG}
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

pushd /nvidia-jetson/Linux_for_Tegra &>/dev/null
case ${COMMAND:-} in
flash)
    flash
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
