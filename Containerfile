ARG UBUNTU_VERSION=20.04
FROM docker.io/library/ubuntu:${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C

ARG SOFTWARE_DEPS_LIST="curl iproute2 sudo usbutils"
RUN printf "Updating the package cache ...\n"; \
    apt-get --yes update; \
    printf "Upgrading the image ...\n"; \
    apt-get --yes upgrade; \
    printf "Installing software ...\n"; \
    apt-get --yes install ${SOFTWARE_DEPS_LIST}; \
    printf "Cleaning up ...\n"; \
    rm --recursive --force /var/lib/apt/lists/*

WORKDIR /nvidia-jetson

ARG JETSON_FIRMWARE_RELEASE
RUN echo JETSON_FIRMWARE_RELEASE=${JETSON_FIRMWARE_RELEASE} > /nvidia-jetson/build.manifest

ARG JETSON_DRIVER_BSP_URI=https://developer.nvidia.com/downloads/embedded/l4t/r35_release_v3.1/release/jetson_linux_r35.3.1_aarch64.tbz2
ARG JETSON_DRIVER_BSP=jetson_linux_r35.3.1_aarch64.tbz2
RUN printf "Downloading %s ...\n" ${JETSON_DRIVER_BSP}; \
    curl --location --progress-bar --output /tmp/${JETSON_DRIVER_BSP} ${JETSON_DRIVER_BSP_URI}; \
    printf "Extracting %s ...\n" ${JETSON_DRIVER_BSP}; \
    tar --extract --file=/tmp/${JETSON_DRIVER_BSP} --directory=/nvidia-jetson; \
    printf "Cleaning up ...\n"; \
    rm --force /tmp/${JETSON_DRIVER_BSP}; \
    echo JETSON_DRIVER_BSP=${JETSON_DRIVER_BSP} >> /nvidia-jetson/build.manifest

ARG INSTALL_JETSON_SAMPLE_FS
ARG JETSON_SAMPLE_FS_URI=https://developer.nvidia.com/downloads/embedded/l4t/r35_release_v3.1/release/tegra_linux_sample-root-filesystem_r35.3.1_aarch64.tbz2
ARG JETSON_SAMPLE_FS=tegra_linux_sample-root-filesystem_r35.3.1_aarch64.tbz2
RUN if [ "${INSTALL_JETSON_SAMPLE_FS:-yes}" = "yes" ]; then \
    printf "Downloading %s ...\n" ${JETSON_SAMPLE_FS}; \
    curl --location --progress-bar --output /tmp/${JETSON_SAMPLE_FS} ${JETSON_SAMPLE_FS_URI}; \
    printf "Extracting %s ...\n" ${JETSON_SAMPLE_FS}; \
    tar --extract --file=/tmp/${JETSON_SAMPLE_FS} --directory=/nvidia-jetson/Linux_for_Tegra/rootfs; \
    printf "Cleaning up ...\n"; \
    rm --force /tmp/${JETSON_SAMPLE_FS}; \
    echo JETSON_SAMPLE_FS=${JETSON_SAMPLE_FS} >> /nvidia-jetson/build.manifest; \
    fi

ARG JETSON_BSP_OVERLAY
COPY ${JETSON_BSP_OVERLAY} /tmp/${JETSON_BSP_OVERLAY}
RUN if [ -n "${JETSON_BSP_OVERLAY:-}" ]; then \
    printf "Extracting %s ...\n" ${JETSON_BSP_OVERLAY}; \
    tar --extract --file=/tmp/${JETSON_BSP_OVERLAY} --directory=/nvidia-jetson; \
    printf "Cleaning up ...\n"; \
    rm --force /tmp/${JETSON_BSP_OVERLAY}; \
    echo JETSON_BSP_OVERLAY=${JETSON_BSP_OVERLAY} >> /nvidia-jetson/build.manifest; \
    fi

RUN cd Linux_for_Tegra; ./tools/l4t_flash_prerequisites.sh

ARG SETUP_SCRIPT=files/bsp-setup.sh
COPY --chmod=0750 ${SETUP_SCRIPT} /tmp/bsp-setup.sh
RUN if [ -n "${SETUP_SCRIPT}" ]; then \
    /tmp/bsp-setup.sh && \
    rm --force /tmp/bsp-setup.sh; \
    fi

WORKDIR /nvidia-jetson/Linux_for_Tegra

COPY --chmod=0750 files/entrypoint.sh /nvidia-jetson/entrypoint.sh
ENTRYPOINT [ "/nvidia-jetson/entrypoint.sh" ]
