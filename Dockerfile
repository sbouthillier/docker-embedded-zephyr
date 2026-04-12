FROM ghcr.io/sbouthillier/embedded-base:v1.0.0

ARG USERNAME=ubuntu

ARG ZEPHYR_HOME=/home/${USERNAME}/zephyr-workspace

ARG ZEPHYR_RTOS_VERSION=4.3.0
ARG ZEPHYR_SDK_VERSION=1.0.1

ARG TOOLCHAIN_LIST="xtensa-espressif_esp32_zephyr-elf xtensa-espressif_esp32s2_zephyr-elf xtensa-espressif_esp32s3_zephyr-elf arm-zephyr-eabi"

ARG VIRTUAL_ENV=${ZEPHYR_HOME}/.venv

# Set default shell during Docker image build to bash
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

USER root

# Set non-interactive frontend for apt-get to skip any user confirmation
ENV DEBIAN_FRONTEND=noninteractive

# Install Zephyr required dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    dfu-util=0.11-1 \
    gperf=3.1-1build1 \
    ccache=4.9.1-1\
    locales=2.39-0ubuntu8.7 \
    device-tree-compiler=1.7.0-2build1 \
    libsdl2-dev=2.30.0+dfsg-1ubuntu3.1 \
    libmagic1=1:5.45-3build1 \
    python3-dev=3.12.3-0ubuntu2.1 \
    python3-tk=3.12.3-0ubuntu1 \
    && rm -rf /var/lib/apt/lists/*

# Clean up stale packages
RUN apt-get clean -y \
    && apt-get autoremove --purge -y

# Initialize system locale (required by menuconfig)
RUN sed -i '/^#.*en_US.UTF-8/s/^#//' /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

USER ${USERNAME}

# ---------------------------------------------------------------------
# Set up a python virtual environment and install west

ENV VIRTUAL_ENV=${VIRTUAL_ENV}
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"
RUN python3 -m venv ${VIRTUAL_ENV} \
    && python3 -m pip install --no-cache-dir west==1.5.0

# ----------------------------------------------------------------------
# Zephyr RTOS

# Set Zephyr environment variables
ENV ZEPHYR_RTOS_VERSION=${ZEPHYR_RTOS_VERSION}

# Install Zephyr and SDK
COPY --chown=${USERNAME}:${USERNAME} west.yml ${ZEPHYR_HOME}/west-manifest/west.yml

WORKDIR ${ZEPHYR_HOME}
RUN west init -l west-manifest \
    && west update --narrow -o=--depth=1 \
    && west zephyr-export \
    && west packages pip --install \
    && west sdk install --version ${ZEPHYR_SDK_VERSION} -b ${ZEPHYR_HOME} -t ${TOOLCHAIN_LIST}

ENV ZEPHYR_SDK_INSTALL_DIR=${ZEPHYR_HOME}/zephyr-sdk-${ZEPHYR_SDK_VERSION}

# ----------------------------------------------------------------------
# Entry point

# Activate the python and Zephyr environment for shell sessions
RUN echo "source ${VIRTUAL_ENV}/bin/activate" >> /home/${USERNAME}/.bashrc \
    && echo "source ${ZEPHYR_HOME}/zephyr/zephyr-env.sh" >> /home/${USERNAME}/.bashrc

WORKDIR /home/${USERNAME}/workspace
