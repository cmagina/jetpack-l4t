#! /bin/bash

set -o errexit  # abort on nonzero exitstatus
set -o nounset  # abort on unbound variable
set -o pipefail # don't hide errors within pipes
# set -o xtrace   # display expanded commands and arguments

# Defaults
IMAGE_NAME=jetson-l4t
DEFAULT_SETUP_SCRIPT="files/bsp-setup.sh"
USER_BIN_PATH="${HOME}/.local/bin"
SCRIPT_BASE_DIR="$(dirname $(realpath $0))"

JETSON_FIRMWARE_RELEASE_ARRAY=(
    "35.4.1"
    "35.3.1"
    "35.2.1"
)

declare -A JETSON_DRIVER_BSP_MAP=(
    ["35.4.1"]="Jetson_Linux_R35.4.1_aarch64.tbz2"
    ["35.3.1"]="Jetson_Linux_R35.3.1_aarch64.tbz2"
    ["35.2.1"]="Jetson_Linux_R35.2.1_aarch64.tbz2"
)

declare -A JETSON_DRIVER_BSP_URI_MAP=(
    ["35.4.1"]="https://developer.nvidia.com/downloads/embedded/l4t/r35_release_v4.1/release/jetson_linux_r35.4.1_aarch64.tbz2"
    ["35.3.1"]="https://developer.download.nvidia.com/embedded/L4T/r35_Release_v3.1/release/Jetson_Linux_R35.3.1_aarch64.tbz2"
    ["35.2.1"]="https://developer.nvidia.com/downloads/jetson-linux-r3521-aarch64tbz2"
)

declare -A JETSON_ROOT_FS_MAP=(
    ["35.4.1"]="Tegra_Linux_Sample-Root-Filesystem_R35.4.1_aarch64.tbz2"
    ["35.3.1"]="tegra_linux_sample-root-filesystem_r35.3.1_aarch64.tbz2"
    ["35.2.1"]="Tegra_Linux_Sample-Root-Filesystem_R35.2.1_aarch64.tbz2"
)

declare -A JETSON_ROOT_FS_URI_MAP=(
    ["35.4.1"]="https://developer.nvidia.com/downloads/embedded/l4t/r35_release_v4.1/release/tegra_linux_sample-root-filesystem_r35.4.1_aarch64.tbz2"
    ["35.3.1"]="https://developer.nvidia.com/downloads/embedded/l4t/r35_release_v3.1/release/tegra_linux_sample-root-filesystem_r35.3.1_aarch64.tbz2"
    ["35.2.1"]="https://developer.nvidia.com/downloads/linux-sample-root-filesystem-r3521aarch64tbz2"
)

declare -A DEFAULT_UBUNTU_VERSION_MAP=(
    ["35.4.1"]="20.04"
    ["35.3.1"]="20.04"
    ["35.2.1"]="20.04"
)

declare -a PODMAN_ARGS=(
    --rm
    --cap-add=all
)

function print_arr() {
    local -n arr=$1

    printf "\t"
    printf "%s  " ${arr[@]}
    printf "\n"
}

function usage() {
    printf "%s [options] [-b | -i | -u] -t <image tag>\n" $0
    printf "Commands:\n"
    printf "\t-b                                - build the %s rootful image\n" ${IMAGE_NAME}
    printf "\t-i                                - install the run script to %s\n" "${USER_BIN_PATH}"
    printf "\t-u                                - uninstall the run script from %s\n" "${USER_BIN_PATH}"
    printf "Options:\n"
    printf "\t-c                                - clean up build artifacts\n"
    printf "\t-d <jetson driver bsp>            - path or url to the jetson driver bsp\n"
    printf "\t-f <jetson firmware release>      - jetson firmware release version\n"
    printf "\t-g <ubuntu os version>            - ubuntu version to base image on (i.e. 20.04)\n"
    printf "\t-n                                - Do not install the sample filesystem\n"
    printf "\t-m <jetson root filesystem>       - path or url to a jetson root filesystem\n"
    printf "\t-n                                - Do not install the sample filesystem\n"
    printf "\t-p <jetson bsp overlay>           - path or url to the jetson bsp overlay\n"
    printf "\t-s <path to setup script>         - script to perform final tasks as part of image build\n"
    printf "\t                                    i.e. apply_binaries.sh (default: %s)\n" "${DEFAULT_SETUP_SCRIPT}"
    printf "\t-v                                - verbose\n"
    printf "\t-h                                - usage\n"
    printf "Supported Jetson Firmware Releases:\n"
    print_arr JETSON_FIRMWARE_RELEASE_ARRAY
}

function get_file() {
    FILE_URI="${1}"
    FILENAME="${2:-}"

    if [[ -z "${FILENAME:-}" ]]; then
        FILENAME="$(basename "${FILE_URI}")"
    fi

    if [[ ! -f "${FILE_URI}" ]]; then
        printf "Downloading the file %s to the %s directory ...\n" "${FILENAME}" ${JETSON_FIRMWARE_RELEASE}
        curl --location --progress-bar --continue-at - --output "${SCRIPT_BASE_DIR}/${JETSON_FIRMWARE_RELEASE}/${FILENAME}" "${FILE_URI}"
    elif [[ "$(realpath ${FILE_URI})" != "${SCRIPT_BASE_DIR}/${JETSON_FIRMWARE_RELEASE}/${FILENAME}" ]]; then
        printf "Copying the file %s to the %s directory ...\n" "${FILENAME}" ${JETSON_FIRMWARE_RELEASE}
        cp ${VERBOSE:-} "${FILE_URI}" "${SCRIPT_BASE_DIR}/${JETSON_FIRMWARE_RELEASE}/${FILENAME}"
    fi
}

function build_cleanup() {
    if [[ "${CLEAN_BUILD:-no}" == "yes" ]]; then
        printf "Cleaning up the build ...\n"
        rm ${VERBOSE:-} --force --recursive ${JETSON_FIRMWARE_RELEASE:-?}
    fi
}

function build_image() {
    if [[ ! "${JETSON_FIRMWARE_RELEASE_ARRAY[@]}" =~ "${JETSON_FIRMWARE_RELEASE}" ]]; then
        if [[ -z "${JETSON_DRIVER_BSP:-}" ]]; then
            printf "ERROR: Unrecognized firmware version, need to provide the driver BSP package.\n"
            exit 1
        fi

        if [[ "${INSTALL_JETSON_ROOT_FS:-yes}" == "yes" && -z "${JETSON_ROOT_FS:-}" ]]; then
            printf "ERROR: Unrecognized firmware version, need to provide a rootfs or specify '-n' on the commandline.\n"
            exit 1
        fi
    fi

    UBUNTU_VERSION=${UBUNTU_VERSION:-${DEFAULT_UBUNTU_VERSION_MAP[${JETSON_FIRMWARE_RELEASE}]:-20.04}}

    printf "Building the %s:%s container ...\n" ${IMAGE_NAME} ${JETSON_FIRMWARE_RELEASE}

    mkdir ${VERBOSE:-} --parents "${SCRIPT_BASE_DIR}/${JETSON_FIRMWARE_RELEASE}"

    trap build_cleanup EXIT

    PODMAN_ARGS+=(
        --build-arg BSP_DOWNLOADS="${JETSON_FIRMWARE_RELEASE}/"
        --build-arg UBUNTU_VERSION="${UBUNTU_VERSION}"
    )

    if [[ -f "${SETUP_SCRIPT:-}" ]]; then
        get_file "${SETUP_SCRIPT}"
        SETUP_SCRIPT="$(basename ${SETUP_SCRIPT})"
    fi

    if [[ -z "${JETSON_DRIVER_BSP:-}" ]]; then
        JETSON_DRIVER_BSP_URI="${JETSON_DRIVER_BSP_URI_MAP[${JETSON_FIRMWARE_RELEASE}]:-}"
        JETSON_DRIVER_BSP="${JETSON_DRIVER_BSP_MAP[${JETSON_FIRMWARE_RELEASE}]:-}"
        get_file "${JETSON_DRIVER_BSP_URI}" "${JETSON_DRIVER_BSP}"
    elif [[ -f "${JETSON_DRIVER_BSP}" ]]; then
        get_file "${JETSON_DRIVER_BSP}"
    else
        printf "ERROR: Failed to get the Jetson driver BSP.\n"
        exit 1
    fi

    PODMAN_ARGS+=(
        --build-arg JETSON_DRIVER_BSP="$(basename "${JETSON_DRIVER_BSP}")"
    )

    if [[ "${INSTALL_JETSON_ROOT_FS:-yes}" == "yes" ]]; then
        if [[ -z "${JETSON_ROOT_FS:-}" ]]; then
            JETSON_ROOT_FS_URI="${JETSON_ROOT_FS_URI_MAP[${JETSON_FIRMWARE_RELEASE}]:-}"
            JETSON_ROOT_FS="${JETSON_ROOT_FS_MAP[${JETSON_FIRMWARE_RELEASE}]:-}"
            get_file "${JETSON_ROOT_FS_URI}" "${JETSON_ROOT_FS}"
        elif [[ -f "${JETSON_ROOT_FS}" ]]; then
            get_file "${JETSON_ROOT_FS}"
        else
            printf "ERROR: Failed to get the Jetson root filesystem.\n"
            exit 1
        fi

        PODMAN_ARGS+=(
            --build-arg JETSON_ROOT_FS="$(basename "${JETSON_ROOT_FS}")"
        )
    elif [[ -z "${SETUP_SCRIPT:-}" ]]; then
        SETUP_SCRIPT="files/no-rootfs-bsp-setup.sh"
    fi

    if [[ -n "${JETSON_BSP_OVERLAY:-}" ]]; then
        get_file "${JETSON_BSP_OVERLAY}"
        PODMAN_ARGS+=(
            --build-arg JETSON_BSP_OVERLAY="$(basename "${JETSON_BSP_OVERLAY}")"
        )
    fi

    PODMAN_ARGS+=(
        --build-arg JETSON_FIRMWARE_RELEASE=${JETSON_FIRMWARE_RELEASE}
        --build-arg SETUP_SCRIPT="${SETUP_SCRIPT:-${DEFAULT_SETUP_SCRIPT}}"
    )

    sudo podman build ${PODMAN_ARGS[@]} --file Containerfile --tag ${IMAGE_NAME}:${JETSON_FIRMWARE_RELEASE}
}

function install_files() {
    printf "Installing the jetson-l4t.sh run script as %s/jetson-l4t ...\n" "${USER_BIN_PATH}"
    install ${VERBOSE:-} -D --mode=0755 jetson-l4t.sh "${USER_BIN_PATH}/jetson-l4t"
}

function remove_files() {
    printf "Removing the %s/jetson-l4t run script ...\n" "${USER_BIN_PATH}"
    rm ${VERBOSE:-} --force "${USER_BIN_PATH}/jetson-l4t"
}

##
## MAIN
##

if [[ $# -le 0 ]]; then
    usage
    exit
fi

while getopts ":bcd:f:g:im:np:s:uvh" opt; do
    case "${opt}" in
    b)
        COMMAND=build
        ;;
    c)
        CLEAN_BUILD="yes"
        ;;
    d)
        JETSON_DRIVER_BSP="${OPTARG}"
        ;;
    f)
        JETSON_FIRMWARE_RELEASE="${OPTARG}"
        ;;
    g)
        UBUNTU_VERSION="${OPTARG}"
        ;;
    i)
        INSTALL_FILES="yes"
        ;;
    m)
        JETSON_ROOT_FS="${OPTARG}"
        ;;
    n)
        INSTALL_JETSON_ROOT_FS="no"
        ;;
    p)
        JETSON_BSP_OVERLAY="${OPTARG}"
        ;;
    s)
        SETUP_SCRIPT="${OPTARG}"
        ;;
    u)
        UNINSTALL_FILES="yes"
        ;;
    v)
        set -o xtrace
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

if [[ "${INSTALL_FILES:-no}" == "yes" ]]; then
    install_files
    [[ -z "${COMMAND:-}" ]] && exit $?
elif [[ "${UNINSTALL_FILES:-no}" == "yes" ]]; then
    remove_files
    [[ -z "${COMMAND:-}" ]] && exit $?
fi

if [[ -z "${JETSON_FIRMWARE_RELEASE:-}" ]]; then
    printf "Need to specify a Jetson firmware release.\n"
    printf "Automatically supported Jetson Firmware Releases:\n"
    print_arr JETSON_FIRMWARE_RELEASE_ARRAY
    exit
fi

case ${COMMAND:-} in
build)
    build_image
    exit $?
    ;;
remove)
    remove_image
    exit $?
    ;;
esac

usage
