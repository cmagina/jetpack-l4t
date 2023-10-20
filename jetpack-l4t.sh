#! /bin/bash

set -o errexit  # abort on nonzero exitstatus
set -o nounset  # abort on unbound variable
set -o pipefail # don't hide errors within pipes
# set -o xtrace   # display expanded commands and arguments

##
## Default Variables
##

IMAGE_NAME=jetpack-l4t
DEFAULT_ROOTDEV=external
DEFAULT_SETUP_SCRIPT="files/bsp-setup.sh"
JETPACK_L4T_PATH="${HOME}/.local/share/jetpack-l4t"

if [[ -f "${JETPACK_L4T_PATH}/config.sh" ]]; then
    source "${JETPACK_L4T_PATH}/config.sh"
else
    printf "Failed to find the default config file, %s, exiting.\n" "${JETPACK_L4T_PATH}/config.sh"
    exit 1
fi

if [[ -f "${HOME}/.config/jetpack-l4t.conf" ]]; then
    source "${HOME}/.config/jetpack-l4t.conf"
fi

function usage() {
    printf "%s [options] -c <command>\n" $(basename $0)
    printf "Required:\n"
    printf "\t-c <command>                      - command to run\n"
    printf "Commands:\n"
    printf "\tbuild                             - build the %s rootful image\n" ${IMAGE_NAME}
    printf "\tflash                             - flash the board\n"
    printf "\tlist                              - list available firmware releases\n"
    printf "\tmanifest                          - print the image build manifest\n"
    printf "\tremove                            - remove the firmware release\n"
    printf "\tshell                             - drop to a shell inside the container\n"
    printf "Boardctl Commands\n"
    printf "\tpower_on                          - power on the board\n"
    printf "\tpower_off                         - power off the board\n"
    printf "\trecovery                          - put the board into recovery mode\n"
    printf "\treset                             - reset the board\n"
    printf "\tstatus                            - get the power status of the board\n"
    printf "Options:\n"
    printf "\t-f <jetpack firmware release>     - jetpack firmware release version\n"
    printf "\t-t <image tag>                    - image version tag\n"
    printf "\t-v                                - verbose\n"
    printf "\t-h                                - usage\n"
    printf "Build Options:\n"
    printf "\t-d <jetpack driver bsp>           - path or url to the jetpack driver bsp\n"
    printf "\t-i <ubuntu os version>            - ubuntu version to base image on (i.e. 20.04)\n"
    printf "\t-m <jetpack root filesystem>      - path or url to a jetpack root filesystem\n"
    printf "\t-n                                - Do not install the sample filesystem\n"
    printf "\t-o <jetpack bsp overlay>          - path or url to the jetpack bsp overlay\n"
    printf "\t-s <path to setup script>         - script to perform final tasks as part of image build\n"
    printf "\t                                    i.e. apply_binaries.sh (default: %s)\n" "${DEFAULT_SETUP_SCRIPT}"
    printf "Flash Options:\n"
    printf "\t-b <jetpack board config>         - jetpack board config to flash\n"
    printf "\t-p <platform>                     - platform to flash\n"
    printf "\t-r <rootdev>                      - root device to flash (default %s)\n" ${DEFAULT_ROOTDEV}
    printf "\t-u <USB ID>                       - flash serial usb device ID (i.e. 7023)\n"
    printf "Supported Platforms:\n"
    printf "\t%s\n" ${PLATFORM_ARRAY[@]}
    printf "Supported Boardctl Platforms:\n"
    printf "\t%s\n" ${!BOARDCTL_PLATFORM_ARRAY[@]}
    printf "Supported JetPack Firmware Releases:\n"
    printf "\t%s\n" ${JETPACK_FIRMWARE_RELEASE_ARRAY[@]}
}

function get_file() {
    local file_uri="${1}"
    local filename="${2:-}"

    if [[ -z "${filename:-}" ]]; then
        filename="$(basename "${file_uri}")"
        file_uri="$(realpath "${file_uri}")"
    fi

    if [[ ! -f "${file_uri}" ]]; then
        printf "Downloading the file %s to the %s directory ...\n" "${filename}" "${JETPACK_L4T_PATH}/${IMAGE_TAG}"
        curl --location --progress-bar --continue-at - --output "${JETPACK_L4T_PATH}/${IMAGE_TAG}/${filename}" "${file_uri}"
    elif [[ "${file_uri}" != "${JETPACK_L4T_PATH}/${IMAGE_TAG}/${filename}" ]]; then
        printf "Copying the file %s to the %s directory ...\n" "${filename}" "${JETPACK_L4T_PATH}/${IMAGE_TAG}"
        cp ${VERBOSE:-} "${file_uri}" "${JETPACK_L4T_PATH}/${IMAGE_TAG}/${filename}"
    else
        printf "File %s already in the directory %s\n" "${filename}" "${JETPACK_L4T_PATH}/${IMAGE_TAG}"
    fi
}

function build_cleanup() {
    if [[ "${CLEANUP_BUILD:-yes}" == "yes" ]]; then
        printf "Cleaning up the build ...\n"
        rm ${VERBOSE:-} --force --recursive ${IMAGE_TAG:-?}
    fi
}

function build_image() {
    if [[ -z "${JETPACK_FIRMWARE_RELEASE:-}" ]]; then
        if [[ -z "${JETPACK_DRIVER_BSP:-}" ]]; then
            printf "Need to specify a supported jetpack firmware release or a jetpack driver bsp.\n"
            printf "i.e. -f <jetpack firmware release> or -d <jetpack driver bsp>\n"
            printf "Supported JetPack Firmware Releases:\n"
            printf "\t%s\n" ${JETPACK_FIRMWARE_RELEASE_ARRAY[@]}
            exit 1
        elif [[ -z "${IMAGE_TAG:-}" ]]; then
            printf "Need to specifiy a jetpack firmware release or image tag.\n"
            printf "i.e. -f <jetpack firmware release> or -t <image tag>\n"
            exit 1
        else
            JETPACK_FIRMWARE_RELEASE=${IMAGE_TAG}
        fi
    elif [[ ! "${JETPACK_FIRMWARE_RELEASE_ARRAY[@]}" =~ "${JETPACK_FIRMWARE_RELEASE}" ]]; then
        if [[ -z "${JETPACK_DRIVER_BSP:-}" ]]; then
            printf "Unrecognized firmware version, need to provide the driver BSP package.\n"
            printf "i.e. -d <jetpack driver bsp>\n"
            exit 1
        fi

    fi

    IMAGE_TAG="${IMAGE_TAG:-${JETPACK_FIRMWARE_RELEASE}}"
    UBUNTU_VERSION=${UBUNTU_VERSION:-${DEFAULT_UBUNTU_VERSION_MAP[${JETPACK_FIRMWARE_RELEASE}]:-20.04}}

    printf "Building the %s:%s container with firmware release %s ...\n" ${IMAGE_NAME} ${IMAGE_TAG} ${JETPACK_FIRMWARE_RELEASE}

    mkdir ${VERBOSE:-} --parents "${JETPACK_L4T_PATH}/${IMAGE_TAG}"

    trap build_cleanup EXIT

    PODMAN_BUILD_ARGS+=(
        --build-arg BSP_DOWNLOADS="${IMAGE_TAG}/"
        --build-arg UBUNTU_VERSION="${UBUNTU_VERSION}"
    )

    if [[ -f "${SETUP_SCRIPT:-}" ]]; then
        get_file "${SETUP_SCRIPT}"
        SETUP_SCRIPT="$(basename ${SETUP_SCRIPT})"
    fi

    if [[ -z "${JETPACK_DRIVER_BSP:-}" && "${JETPACK_FIRMWARE_RELEASE_ARRAY[@]}" =~ "${JETPACK_FIRMWARE_RELEASE}" ]]; then
        JETPACK_DRIVER_BSP_URI="${JETPACK_DRIVER_BSP_URI_MAP[${JETPACK_FIRMWARE_RELEASE}]:-}"
        JETPACK_DRIVER_BSP="${JETPACK_DRIVER_BSP_MAP[${JETPACK_FIRMWARE_RELEASE}]:-}"
        get_file "${JETPACK_DRIVER_BSP_URI}" "${JETPACK_DRIVER_BSP}"
    elif [[ -f "${JETPACK_DRIVER_BSP:-}" ]]; then
        get_file "${JETPACK_DRIVER_BSP}"
    else
        printf "Need to specify a supported jetpack firmware release or a jetpack driver bsp.\n"
        printf "i.e. -f <jetpack firmware release> or -d <jetpack driver bsp>\n"
        printf "Supported JetPack Firmware Releases:\n"
        printf "\t%s\n" ${JETPACK_FIRMWARE_RELEASE_ARRAY[@]}
        exit 1
    fi

    PODMAN_BUILD_ARGS+=(
        --build-arg JETPACK_DRIVER_BSP="$(basename "${JETPACK_DRIVER_BSP}")"
    )

    if [[ "${INSTALL_JETPACK_ROOT_FS:-yes}" == "yes" ]]; then
        if [[ -z "${JETPACK_ROOT_FS:-}" && "${JETPACK_FIRMWARE_RELEASE_ARRAY[@]}" =~ "${JETPACK_FIRMWARE_RELEASE}" ]]; then
            JETPACK_ROOT_FS_URI="${JETPACK_ROOT_FS_URI_MAP[${JETPACK_FIRMWARE_RELEASE}]:-}"
            JETPACK_ROOT_FS="${JETPACK_ROOT_FS_MAP[${JETPACK_FIRMWARE_RELEASE}]:-}"
            get_file "${JETPACK_ROOT_FS_URI}" "${JETPACK_ROOT_FS}"
        elif [[ -f "${JETPACK_ROOT_FS:-}" ]]; then
            get_file "${JETPACK_ROOT_FS}"
        else
            printf "Need to specify a supported jetpack firmware release or a jetpack root filesystem or no root filesystem.\n"
            printf "i.e. -f <jetpack firmware release> or -m <jetpack root filesystem> or -n\n"
            printf "Supported JetPack Firmware Releases:\n"
            printf "\t%s\n" ${JETPACK_FIRMWARE_RELEASE_ARRAY[@]}
            exit 1

        fi

        PODMAN_BUILD_ARGS+=(
            --build-arg JETPACK_ROOT_FS="$(basename "${JETPACK_ROOT_FS}")"
        )
    elif [[ -z "${SETUP_SCRIPT:-}" ]]; then
        SETUP_SCRIPT="files/no-rootfs-bsp-setup.sh"
    fi

    if [[ -n "${JETPACK_BSP_OVERLAY:-}" ]]; then
        get_file "${JETPACK_BSP_OVERLAY}"
        PODMAN_BUILD_ARGS+=(
            --build-arg JETPACK_BSP_OVERLAY="$(basename "${JETPACK_BSP_OVERLAY}")"
        )
    fi

    PODMAN_BUILD_ARGS+=(
        --build-arg JETPACK_FIRMWARE_RELEASE=${JETPACK_FIRMWARE_RELEASE}
        --build-arg SETUP_SCRIPT="${SETUP_SCRIPT:-${DEFAULT_SETUP_SCRIPT}}"
    )

    sudo podman build ${PODMAN_BUILD_ARGS[@]} --tag ${IMAGE_NAME}:${IMAGE_TAG} ${JETPACK_L4T_PATH}
}

function run() {
    local run_cmd=${1}
    shift
    local -a run_args=("${@:-}")

    if [[ -z "${IMAGE_TAG:-}" ]]; then
        printf "Need to specify an image\n"
        printf "\ti.e. -t <image tag>\n"
        list_images
        exit 1
    fi

    if [[ -n "${VERBOSE:-}" ]]; then
        run_args+=("-v")
    fi

    sudo podman run --name ${IMAGE_NAME}-${IMAGE_TAG}-${run_cmd} ${PODMAN_RUN_ARGS[@]} ${IMAGE_NAME}:${IMAGE_TAG} -c ${run_cmd} ${run_args[@]:-}
}

function boardctl() {
    local boardctl_cmd=$1
    local target_board=${2:-}

    if [[ -z "${PLATFORM:-}" || ! "${!BOARDCTL_PLATFORM_ARRAY[@]}" =~ "${PLATFORM:-}" ]]; then
        printf "Unsupported or unspecified board control platform\n"
        if [[ -n "${PLATFORM:-}" ]]; then
            printf "\t%s\n" ${PLATFORM}
        fi
        printf "Supported Board Control Platforms:\n"
        printf "\t%s\n" ${!BOARDCTL_PLATFORM_ARRAY[@]}
        exit 1
    fi

    target_board=${target_board:-${BOARDCTL_PLATFORM_ARRAY[${PLATFORM}]}}

    run ${boardctl_cmd} -t ${target_board}
}

function check_for_nvidia_usb_device_id() {
    local platform_recovery_device_id="$1"
    lsusb | grep --quiet "ID 0955:${platform_recovery_device_id} NVIDIA Corp."
    echo $?
}

function flash() {
    if [[ -z "${PLATFORM_RECOVERY_DEVICE_ID:-}" ]]; then
        case ${PLATFORM} in
        agxorin)
            local platform_recovery_device_id="7023"
            local platform_serial_device_id="7045"
            ;;
        igxorin)
            local platform_recovery_device_id="7023"
            ;;
        orinnx)
            local platform_recovery_device_id="7323"
            ;;
        orinnano)
            local platform_recovery_device_id="7523"
            ;;
        xaviernx)
            local platform_recovery_device_id="7e19"
            ;;
        esac
    else
        local platform_recovery_device_id="${PLATFORM_RECOVERY_DEVICE_ID}"
    fi

    if [[ -z "${JETPACK_BOARD_CONFIG:-}" && ! "${PLATFORM_ARRAY[@]}" =~ "${PLATFORM}" ]]; then
        printf "Need to specify a jetpack board config or a supported jetpack board.\n"
        printf "i.e. -b <jetpack board config>\n"
        printf "Supported Platforms:\n"
        printf "\t%s\n" ${PLATFORM_ARRAY[@]}
        exit 1
    fi

    if [[ -n "${platform_serial_device_id:-}" ]]; then
        printf "Checking for the platform usb serial device id '%s' ...\n" "ID 0955:${platform_serial_device_id} NVIDIA Corp."
        local serial_status=$(check_for_nvidia_usb_device_id "${platform_serial_device_id}")
        if [[ ${serial_status} -ne 0 ]]; then
            printf "Could not find the platform usb serial device id '%s', put the board into recovery manually ...\n" "ID 0955:${platform_serial_device_id} NVIDIA Corp."
            read -p "Press Enter to continue or Ctrl+C to quit"
        else
            printf "Putting the platform into recovery ...\n"
            boardctl recovery
        fi
    fi

    printf "Checking for the platform usb recovery device id '%s' ...\n" "ID 0955:${platform_recovery_device_id} NVIDIA Corp."
    local recovery_status=$(check_for_nvidia_usb_device_id "${platform_recovery_device_id}")
    if [[ ${recovery_status} -ne 0 ]]; then
        printf "Jetson recovery mode usb device '%s' not found, try putting the platform into recovery mode ...\n" "ID 0955:${platform_recovery_device_id} NVIDIA Corp."
        read -p "Press Enter to continue or Ctrl+C to quit"

        printf "Checking for the platform usb recovery device id '%s' ...\n" "ID 0955:${platform_recovery_device_id} NVIDIA Corp."
        recovery_status=$(check_for_nvidia_usb_device_id "${platform_recovery_device_id}")
        if [[ ${recovery_status} -ne 0 ]]; then
            printf "\nJetson recovery mode usb device '%s' not found, exiting.\n" "ID 0955:${platform_recovery_device_id} NVIDIA Corp."
            printf "Check that the platform recovery port is connected to this host using a usb cable that supports data before trying again.\n"
            exit 1
        fi
    fi

    run flash -b ${JETPACK_BOARD_CONFIG:-${JETPACK_BOARD_CONFIG_MAP[$PLATFORM_BOARD]}} -d ${ROOTDEV:-$DEFAULT_ROOTDEV}
}

function list_images() {
    local jetpack_l4t_images=($(sudo podman images --noheading --format "table {{.Tag}}" --filter reference=${IMAGE_NAME}))
    if [[ -n "${jetpack_l4t_images[@]:-}" ]]; then
        printf "Available Images:\n"
        printf "\t%s\n" ${jetpack_l4t_images[@]}
    else
        printf "No images found.\n"
    fi
}

function remove_image() {
    printf "Removing the %s:%s image ...\n" ${IMAGE_NAME} ${IMAGE_TAG}
    sudo podman rmi --force ${IMAGE_NAME}:${IMAGE_TAG}
}

##
## MAIN
##

if [[ $# -le 0 ]]; then
    usage
    exit
fi

while getopts ":b:c:d:f:g:i:m:no:p:r:s:t:vh" opt; do
    case "${opt}" in
    b)
        JETPACK_BOARD_CONFIG=${OPTARG}
        ;;
    c)
        COMMAND=${OPTARG}
        ;;
    d)
        JETPACK_DRIVER_BSP="${OPTARG}"
        ;;
    f)
        JETPACK_FIRMWARE_RELEASE="${OPTARG}"
        ;;
    i)
        UBUNTU_VERSION="${OPTARG}"
        ;;
    m)
        JETPACK_ROOT_FS="${OPTARG}"
        ;;
    n)
        INSTALL_JETPACK_ROOT_FS="no"
        ;;
    o)
        JETPACK_BSP_OVERLAY="${OPTARG}"
        ;;
    p)
        PLATFORM=${OPTARG}
        ;;
    r)
        ROOTDEV=${OPTARG}
        ;;
    s)
        SETUP_SCRIPT="${OPTARG}"
        ;;
    t)
        IMAGE_TAG=${OPTARG}
        ;;
    u)
        PLATFORM_RECOVERY_DEVICE_ID=${OPTARG}
        ;;
    v)
        set -o xtrace
        CLEANUP_BUILD="no"
        PODMAN_ARGS+=("--log-level=debug")
        VERBOSE="--verbose"
        ;;
    h)
        usage
        exit
        ;;
    esac
done
shift $((OPTIND - 1))

case ${COMMAND:-} in
build)
    build_image
    exit $?
    ;;
flash)
    if [[ -z "${PLATFORM:-}" ]]; then
        printf "Unsupported or unspecified platform\n"
        if [[ -n "${PLATFORM:-}" ]]; then
            printf "\t%s\n" ${PLATFORM}
        fi
        printf "Supported Platforms:\n"
        printf "\t%s\n" ${PLATFORM_ARRAY[@]}
        exit 1
    fi

    flash
    exit $?
    ;;
list)
    list_images
    exit $?
    ;;
manifest)
    run manifest
    exit $?
    ;;
power_on | power_off | recovery | reset | status)
    boardctl ${COMMAND}
    exit $?
    ;;
remove)
    remove_image
    exit $?
    ;;
shell)
    printf "Opening a shell in %s ...\n" ${IMAGE_NAME}
    run shell
    exit $?
    ;;
esac

usage
