#! /bin/bash

set -o errexit  # abort on nonzero exitstatus
set -o nounset  # abort on unbound variable
set -o pipefail # don't hide errors within pipes
# set -o xtrace   # display expanded commands and arguments

# Defaults
IMAGE_NAME=jetson-l4t
DEFAULT_JETSON_ROOTDEV=external

JETSON_ARRAY=(
    agxorin
    igxorin
    orinnx
    orinnano
    xaviernx
)

JETSON_FIRMWARE_RELEASE_ARRAY=(
    35.3.1
    35.2.1
)

PODMAN_BUILD_ARGS=(
    --rm
)

PODMAN_RUN_ARGS=(
    --interactive
    --tty
    --rm
    --privileged
    --name ${IMAGE_NAME}
    --volume /dev:/dev
    --volume /sys:/sys
)

function usage() {
    printf "%s [options] -c <command> -t <image tag>\n" $0
    printf "Required:\n"
    printf "\t-c <command>                      - command to run\n"
    printf "\t-t <image tag>                    - image version tag\n"
    printf "Options:\n"
    printf "\t-b <jetson board config>          - jetson board config to flash\n"
    printf "\t-d <rootdev>                      - root device to flash (default %s)\n" ${DEFAULT_JETSON_ROOTDEV}
    printf "\t-i <USB ID>                       - flash serial usb device ID (i.e. 7023)\n"
    printf "\t-j <jetson>                       - jetson to flash\n"
    printf "\t-v                                - verbose\n"
    printf "\t-h                                - usage\n"
    printf "Commands:\n"
    printf "\tflash                             - flash the jetson and cleanup\n"
    printf "\tlist                              - list available image tags\n"
    printf "\tmanifest                          - print the image build manifest\n"
    printf "\tpower_on                          - power on the jetson\n"
    printf "\tpower_off                         - power off the jetson\n"
    printf "\trecovery                          - put the jetson into recovery mode\n"
    printf "\treset                             - reset the jetson\n"
    printf "\tstatus                            - get the power status of the jetson\n"
    printf "\tshell                             - drop to a shell inside the container\n"
    printf "Supported Jetsons:\n"
    printf "\t"
    printf "%s " ${JETSON_ARRAY[@]}
    printf "\n"
    printf "Supported Jetson Firmware Releases:\n"
    printf "\t"
    printf "%s " ${JETSON_FIRMWARE_RELEASE_ARRAY[@]}
    printf "\n"
}

function run() {
    local run_args="${@:-}"

    if [[ -z "${IMAGE_TAG:-}" ]]; then
        printf "Need to specify the image tag.\n"
        exit 1
    fi

    sudo podman run ${PODMAN_RUN_ARGS[@]} ${IMAGE_NAME}:${IMAGE_TAG} ${run_args:-} ${COMMAND_ARGS[@]:-}
}

function check_for_nvidia_usb_device_id() {
    local jetson_recovery_device_id="$1"
    lsusb | grep --quiet "ID 0955:${jetson_recovery_device_id} NVIDIA Corp."
    echo $?
}

function flash() {
    if [[ -z "${JETSON_BOARD_CONFIG:-}" ]]; then
        printf "Need to specify a jetson board config, i.e. -b jetson-agx-orin-devkit.\n"
        exit 1
    fi

    if [[ -z "${JETSON_RECOVERY_DEVICE_ID:-}" ]]; then
        if [[ -z "${JETSON_BOARD:-}" ]]; then
            printf "Need to specify a jetson board, i.e. -j agxorin.\n"
            exit 1
        fi

        case ${JETSON_BOARD} in
        agxorin)
            local jetson_recovery_device_id="7023"
            local jetson_serial_device_id="7045"
            ;;
        igxorin)
            local jetson_recovery_device_id="7023"
            ;;
        orinnx)
            local jetson_recovery_device_id="7323"
            ;;
        orinnano)
            local jetson_recovery_device_id="7523"
            ;;
        xaviernx)
            local jetson_recovery_device_id="7e19"
            ;;
        *)
            printf "Unsupported jetson board: %s\n" ${JETSON_BOARD}
            exit 1
            ;;
        esac
    else
        local jetson_recovery_device_id="${JETSON_RECOVERY_DEVICE_ID}"
    fi

    if [[ -n "${jetson_serial_device_id:-}" ]]; then
        printf "Checking for the jetson usb serial device id '%s' ...\n" "ID 0955:${jetson_serial_device_id} NVIDIA Corp."
        local serial_status=$(check_for_nvidia_usb_device_id "${jetson_serial_device_id}")
        if [[ ${serial_status} -ne 0 ]]; then
            printf "Could not find the jetson usb serial device id '%s', put the board into recovery manually ...\n" "ID 0955:${jetson_serial_device_id} NVIDIA Corp."
            read -p "Press Enter to continue or Ctrl+C to quit"
        else
            printf "Putting the jetson into recovery ...\n"
            run -c recovery
        fi
    fi

    printf "Checking for the jetson usb recovery device id '%s' ...\n" "ID 0955:${jetson_recovery_device_id} NVIDIA Corp."
    local recovery_status=$(check_for_nvidia_usb_device_id "${jetson_recovery_device_id}")
    if [[ ${recovery_status} -ne 0 ]]; then
        printf "Jetson recovery mode usb device '%s' not found, try putting the jetson into recovery mode ...\n" "ID 0955:${jetson_recovery_device_id} NVIDIA Corp."
        read -p "Press Enter to continue or Ctrl+C to quit"

        printf "Checking for the jetson usb recovery device id '%s' ...\n" "ID 0955:${jetson_recovery_device_id} NVIDIA Corp."
        recovery_status=$(check_for_nvidia_usb_device_id "${jetson_recovery_device_id}")
        if [[ ${recovery_status} -ne 0 ]]; then
            printf "\nERROR: Jetson recovery mode usb device '%s' not found, exiting.\n" "ID 0955:${jetson_recovery_device_id} NVIDIA Corp."
            printf "Check that the jetson recovery port is connected to this host using a usb cable that supports data before trying again.\n"
            exit 1
        fi
    fi

    run -c flash -b ${JETSON_BOARD_CONFIG} -d ${ROOTDEV:-$DEFAULT_JETSON_ROOTDEV}
}

if [[ $# -le 0 ]]; then
    usage
    exit
fi

while getopts ":b:c:d:f:i:j:nr:s:t:vh" opt; do
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
    f)
        JETSON_BSP_OVERLAY_PACKAGE="${OPTARG}"
        ;;
    i)
        JETSON_RECOVERY_DEVICE_ID=${OPTARG}
        ;;
    j)
        JETSON_BOARD=${OPTARG}
        ;;
    n)
        INSTALL_JETSON_SAMPLE_FS="no"
        ;;
    r)
        JETSON_FIRMWARE_RELEASE=${OPTARG}
        ;;
    s)
        SETUP_SCRIPT="${OPTARG}"
        ;;
    t)
        IMAGE_TAG=${OPTARG}
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

case ${COMMAND:-} in
flash)
    flash
    exit $?
    ;;
list)
    sudo podman images --noheading --format "table {{.Tag}}" --filter reference=${IMAGE_NAME}
    exit $?
    ;;
manifest)
    run -c manifest
    exit $?
    ;;
power_on)
    run -c power_on
    exit $?
    ;;
power_off)
    run -c power_off
    exit $?
    ;;
recovery)
    run -c recovery
    exit $?
    ;;
reset)
    run -c reset
    exit $?
    ;;
status)
    run -c status
    exit $?
    ;;
shell)
    printf "Opening a shell in %s ...\n" ${IMAGE_NAME}
    run
    exit $?
    ;;
esac

usage
