ARG IMAGE="ubuntu:22.04"
FROM ${IMAGE}

ENV OSSEC_VERSION=3.7.0
ENV TZ="Europe/Budapest"

COPY default_agent /var/ossec/default_agent
# copy base config
COPY ossec.conf /var/ossec/etc/
# Initialize the data volume configuration
COPY data_dirs.env /data_dirs.env
COPY init.sh /init.sh
# Add the bootstrap script
COPY ossec-server.sh /ossec-server.sh

ARG DEBIAN_FRONTEND="noninteractive"
ARG DEBCONF_NOWARNINGS="yes"
ARG DEBCONF_TERSE="yes"
ARG APT="apt-get -qq -y"

RUN echo "debconf debconf/frontend select ${DEBIAN_FRONTEND}" | debconf-set-selections >/dev/null \
    && echo 'APT::Install-Recommends "false";' | tee /etc/apt/apt.conf.d/99install-recommends \
    && echo 'APT::Get::Assume-Yes "true";' | tee /etc/apt/apt.conf.d/99assume-yes \
    && sed -Ei 's|^(DPkg::Pre-Install-Pkgs .*)|#\1|g' /etc/apt/apt.conf.d/70debconf \
    && debconf-show debconf

RUN mv /etc/apt/apt.conf.d/70debconf . \
    && ${APT} update \
    && ${APT} install apt-utils >/dev/null \
    && mv 70debconf /etc/apt/apt.conf.d \
    && ${APT} upgrade >/dev/null

RUN ${APT} install --no-install-recommends \
    ca-certificates \
    postfix \
    tzdata \
    wget >/dev/null

RUN /usr/bin/wget -q https://updates.atomicorp.com/installers/atomic -O /atomic.sh && \
    sed -i '2i NON_INT=1' /atomic.sh && \
    chmod 755 /atomic.sh && \
    /atomic.sh && \
    ${APT} update && \
	  ${APT} install ossec-hids-server -o Dpkg::Options::="--force-confold" && \
	  chmod 755 /ossec-server.sh && \
	  chmod 755 /init.sh && \
    sync && /init.sh && \
    sync && rm /init.sh

RUN ${APT} autoremove \
    && ${APT} autoclean \
    && ${APT} clean \
    && rm -rf /var/lib/apt/lists/*

# Specify the data volume
VOLUME ["/var/ossec/data"]

# Expose ports for sharing
EXPOSE 514/udp 1514/udp 1515/tcp

#
# Define default command.
#
ENTRYPOINT ["/ossec-server.sh"]
