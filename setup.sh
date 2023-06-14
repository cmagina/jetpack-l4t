#! /bin/bash

set -o errexit  # abort on nonzero exitstatus
set -o nounset  # abort on unbound variable
set -o pipefail # don't hide errors within pipes
# set -o xtrace   # display expanded commands and arguments

# Defaults
IMAGE_NAME=jetson-l4t
DEFAULT_SETUP_SCRIPT="files/bsp-setup.sh"
USER_BIN_PATH="${HOME}/.local/bin"

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
    --cap-add=all
    --privileged
    --name ${IMAGE_NAME}
    --volume /dev:/dev
    --volume /sys:/sys
)

function usage() {
    printf "%s [options] [-b | -i | -r | -u] -t <image tag>\n" $0
    printf "Commands:\n"
    printf "\t-b                                - build the %s rootful image\n" ${IMAGE_NAME}
    printf "\t-i                                - install the %s rootful image and run script\n" ${IMAGE_NAME}
    printf "\t-r                                - remove the %s rootful image\n" ${IMAGE_NAME}
    printf "\t-u                                - uninstall the %s rootful image and run script\n" ${IMAGE_NAME}
    printf "Options:\n"
    printf "\t-f <jetson firmware release>      - jetson firmware release version\n"
    printf "\t-n                                - Do not install the sample filesystem\n"
    printf "\t-p <jetson bsp overlay package>   - path or url to the jetson bsp overlay package\n"
    printf "\t-s <path to setup script>         - script to perform final tasks as part of image build\n"
    printf "\t                                    i.e. apply_binaries.sh (default: %s)\n" "${DEFAULT_SETUP_SCRIPT}"
    printf "\t-t <image tag>                    - image version tag\n"
    printf "\t-v                                - verbose\n"
    printf "\t-h                                - usage\n"
    printf "Supported Jetson Firmware Releases:\n"
    printf "\t"
    printf "%s " ${JETSON_FIRMWARE_RELEASE_ARRAY[@]}
    printf "\n"
}

function build_image() {
    printf "Building the %s:%s rootful container with firmware release %s ...\n" ${IMAGE_NAME} ${IMAGE_TAG} ${JETSON_FIRMWARE_RELEASE}

    case ${JETSON_FIRMWARE_RELEASE} in
    35.2.1)
        PODMAN_BUILD_ARGS+=(
            --build-arg JETSON_DRIVER_BSP_URI=https://developer.nvidia.com/downloads/jetson-linux-r3521-aarch64tbz2
            --build-arg JETSON_DRIVER_BSP=Jetson_Linux_R35.2.1_aarch64.tbz2
            --build-arg JETSON_SAMPLE_FS_URI=https://developer.nvidia.com/downloads/linux-sample-root-filesystem-r3521aarch64tbz2
            --build-arg JETSON_SAMPLE_FS=Tegra_Linux_Sample-Root-Filesystem_R35.2.1_aarch64.tbz2
        )
        ;;
    35.3.1)
        PODMAN_BUILD_ARGS+=(
            --build-arg JETSON_DRIVER_BSP_URI=https://developer.download.nvidia.com/embedded/L4T/r35_Release_v3.1/release/Jetson_Linux_R35.3.1_aarch64.tbz2
            --build-arg JETSON_DRIVER_BSP=Jetson_Linux_R35.3.1_aarch64.tbz2
            --build-arg JETSON_SAMPLE_FS_URI=https://developer.nvidia.com/downloads/embedded/l4t/r35_release_v3.1/release/tegra_linux_sample-root-filesystem_r35.3.1_aarch64.tbz2
            --build-arg JETSON_SAMPLE_FS=tegra_linux_sample-root-filesystem_r35.3.1_aarch64.tbz2
        )
        ;;
    *)
        printf "Unsupported jetson firmware release: %s\n" ${JETSON_FIRMWARE_RELEASE}
        exit 1
        ;;
    esac

    if [[ -f "${SETUP_SCRIPT:-}" ]]; then
        printf "Copying the setup script %s to the build directory ...\n" "$(basename "${SETUP_SCRIPT}")"
        mkdir -p "$(dirname $0)/tmp"
        cp --verbose "${SETUP_SCRIPT}" "$(dirname $0)/tmp/"
        SETUP_SCRIPT="tmp/$(basename ${SETUP_SCRIPT})"
    fi

    if [[ -n "${JETSON_BSP_OVERLAY_PACKAGE:-}" ]]; then
        mkdir -p "$(dirname $0)/tmp"

        if [[ "${JETSON_BSP_OVERLAY_PACKAGE}" =~ "^(https?)://" ]]; then
            printf "Downloading the jetson overlay bsp package %s to the build directory ...\n" "$(basename ${JETSON_BSP_OVERLAY_PACKAGE})"
            curl --location --progress-bar --output "$(dirname $0)/tmp/$(basename ${JETSON_BSP_OVERLAY_PACKAGE})" "${JETSON_BSP_OVERLAY_PACKAGE}"
        elif [[ -f "${JETSON_BSP_OVERLAY_PACKAGE}" ]]; then
            printf "Copying the jetson overlay bsp package %s to the build directory ...\n" "$(basename ${JETSON_BSP_OVERLAY_PACKAGE})"
            cp --verbose "${JETSON_BSP_OVERLAY_PACKAGE}" "$(dirname $0)/tmp/"
        fi

        JETSON_BSP_OVERLAY_PACKAGE="tmp/$(basename ${JETSON_BSP_OVERLAY_PACKAGE})"
        PODMAN_BUILD_ARGS+=(
            --build-arg JETSON_BSP_OVERLAY="${JETSON_BSP_OVERLAY_PACKAGE}"
        )
    fi

    PODMAN_BUILD_ARGS+=(
        --build-arg INSTALL_JETSON_SAMPLE_FS=${INSTALL_JETSON_SAMPLE_FS:-yes}
        --build-arg JETSON_FIRMWARE_RELEASE=${JETSON_FIRMWARE_RELEASE}
        --build-arg SETUP_SCRIPT="${SETUP_SCRIPT:-${DEFAULT_SETUP_SCRIPT}}"
    )

    sudo podman build ${PODMAN_BUILD_ARGS[@]} --file Containerfile --tag ${IMAGE_NAME}:${IMAGE_TAG}

    printf "Cleaning up build ...\n"
    rm --force --recursive tmp
}

function install_files() {
    printf "Installing %s run script ...\n" ${IMAGE_NAME}
    install -D --mode=0755 files/jetson-l4t.sh "${USER_BIN_PATH}/jetson-l4t"
}

function remove_image() {
    printf "Removing the %s image ...\n" ${IMAGE_NAME}
    podman rmi --force ${IMAGE_NAME}:${IMAGE_TAG}
}

function remove_files() {
    printf "Removing the %s run script ...\n" ${IMAGE_NAME}
    rm --force "${USER_BIN_PATH}/jetson-l4t"
}

if [[ $# -le 0 ]]; then
    usage
    exit
fi

while getopts ":vhbirup:f:nr:s:t:" opt; do
    case "${opt}" in
    b)
        COMMAND=build
        ;;
    i)
        COMMAND=install
        ;;
    r)
        COMMAND=remove
        ;;
    u)
        COMMAND=uninstall
        ;;
    p)
        JETSON_BSP_OVERLAY_PACKAGE="${OPTARG}"
        ;;
    f)
        JETSON_FIRMWARE_RELEASE=${OPTARG}
        ;;
    n)
        INSTALL_JETSON_SAMPLE_FS="no"
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

if [[ -z "${IMAGE_TAG:-}" ]]; then
    printf "Need to specify the image tag.\n"
    exit 1
fi

case ${COMMAND:-} in
build | install)
    if [[ -z "${JETSON_FIRMWARE_RELEASE:-}" ]]; then
        printf "Need to specify the Jetson firmware release.\n"
        printf "Supported Jetson Firmware Releases:\n"
        printf "\t"
        printf "%s " ${JETSON_FIRMWARE_RELEASE_ARRAY[@]}
        printf "\n"
        exit 1
    fi

    printf "Installing the %s:%s image ...\n" ${IMAGE_NAME} ${IMAGE_TAG}
    build_image
    EXIT_STATUS=$?
    if [[ "${COMMAND}" == "install" ]]; then
        install_files
    fi
    printf "Install complete.\n"
    exit ${EXIT_STATUS}
    ;;
remove | uninstall)
    printf "Uninstalling the %s:%s image ...\n" ${IMAGE_NAME} ${IMAGE_TAG}
    remove_image
    EXIT_STATUS=$?
    if [[ "${COMMNAD}" == "uninstall" ]]; then
        remove_files
    fi
    printf "Uninstall complete.\n"
    exit ${EXIT_STATUS}
    ;;
esac

usage
