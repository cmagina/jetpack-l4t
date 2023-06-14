#! /bin/bash

set -o errexit  # abort on nonzero exitstatus
set -o nounset  # abort on unbound variable
set -o pipefail # don't hide errors within pipes
# set -o xtrace   # display expanded commands and arguments

# Defaults
IMAGE_NAME=jetson-l4t
DEFAULT_JETSON_ROOTDEV="external"

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
    --cap-add=all
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
    printf "\t-j <jetson>                       - jetson to flash\n"
    printf "\t-v                                - verbose\n"
    printf "\t-h                                - usage\n"
    printf "Commands:\n"
    printf "\tflash                             - flash the jetson and cleanup\n"
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
    sudo podman run ${PODMAN_RUN_ARGS[@]} ${IMAGE_NAME}:${IMAGE_TAG} ${@:-} ${COMMAND_ARGS[@]:-}
}

function flash() {
    if [[ -z "${JETSON_BOARD_CONFIG:-}" ]]; then
        printf "Need to specify a jetson board config, i.e. -b jetson-agx-orin-devkit.\n"
        exit 1
    fi

    run -c flash -b ${JETSON_BOARD_CONFIG} -d ${ROOTDEV:-$DEFAULT_JETSON_ROOTDEV}
}

if [[ $# -le 0 ]]; then
    usage
    exit
fi

while getopts ":vhb:c:d:f:j:nr:s:t:" opt; do
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

if [[ -n "${JETSON_BOARD:-}" ]]; then
    COMMAND_ARGS=("-j ${JETSON_BOARD}")
fi

if [[ -z "${IMAGE_TAG:-}" ]]; then
    printf "Need to specify the image tag.\n"
    exit 1
fi

case ${COMMAND:-} in
flash)
    flash
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
    printf "Opening a shell in %s:%s ...\n" ${IMAGE_NAME} ${IMAGE_TAG}
    run
    exit $?
    ;;
esac

usage
