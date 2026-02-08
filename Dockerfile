# EDCB Linux Docker Build
# Multi-stage build for minimal image size

# =============================================================================
# Stage 1: BonDriver_LinuxMirakc Builder
# =============================================================================
FROM debian:trixie-slim AS bondriver-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    make \
    g++ \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --recurse-submodules --depth 1 \
    https://github.com/matching/BonDriver_LinuxMirakc.git /src/bondriver

WORKDIR /src/bondriver

RUN make

# =============================================================================
# Stage 2: EDCB Builder
# =============================================================================
FROM debian:trixie-slim AS edcb-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    make \
    gcc \
    g++ \
    liblua5.2-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src/edcb
COPY . .

WORKDIR /src/edcb/Document/Unix

RUN make

RUN make install

RUN ls -lh /usr/local/bin/EpgTimerSrv && \
    ls -lh /usr/local/bin/EpgDataCap_Bon && \
    ls -lh /usr/local/lib/edcb/

RUN mkdir -p /var/local/edcb && \
    iconv -f CP932 -t UTF-8 /src/edcb/ini/Bitrate.ini | tr -d '\r' > /var/local/edcb/Bitrate.ini && \
    iconv -f CP932 -t UTF-8 /src/edcb/ini/BonCtrl.ini | tr -d '\r' | sed 's/\.dll$/.so/' > /var/local/edcb/BonCtrl.ini && \
    tr -d '\r' < /src/edcb/ini/ContentTypeText.txt > /var/local/edcb/ContentTypeText.txt

# =============================================================================
# Stage 3: EDCB Material WebUI Source
# =============================================================================
FROM debian:trixie-slim AS emwui-src

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 \
    https://github.com/EMWUI/EDCB_Material_WebUI.git /src/emwui

# =============================================================================
# Stage 4: Runtime
# =============================================================================
FROM debian:trixie-slim AS runtime

LABEL maintainer="na2na"
LABEL description="EDCB Linux - Digital TV Recording Server"
LABEL org.opencontainers.image.source="https://github.com/na2na-p/EDCB"

RUN apt-get update && apt-get install -y --no-install-recommends \
    liblua5.2-0 \
    curl \
    ca-certificates \
    procps \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 -s /bin/bash edcb

COPY --from=edcb-builder /usr/local/bin/EpgTimerSrv /usr/local/bin/
COPY --from=edcb-builder /usr/local/bin/EpgDataCap_Bon /usr/local/bin/
COPY --from=edcb-builder /usr/local/bin/asyncbuf /usr/local/bin/
COPY --from=edcb-builder /usr/local/bin/relayread /usr/local/bin/
COPY --from=edcb-builder /usr/local/bin/tsidmove-edcb /usr/local/bin/
COPY --from=edcb-builder /usr/local/bin/tspgtxt /usr/local/bin/
COPY --from=edcb-builder /usr/local/lib/edcb/ /usr/local/lib/edcb/

COPY --from=bondriver-builder /src/bondriver/BonDriver_LinuxMirakc.so /usr/local/lib/edcb/

RUN mkdir -p \
    /var/local/edcb \
    /var/local/edcb/BonDriver \
    /var/local/edcb/Write \
    /var/local/edcb/EPG \
    /recordings \
    /var/log/edcb && \
    chown -R edcb:edcb /var/local/edcb /recordings /var/log/edcb

COPY --from=edcb-builder /var/local/edcb/Bitrate.ini /var/local/edcb/Bitrate.ini
COPY --from=edcb-builder /var/local/edcb/BonCtrl.ini /var/local/edcb/BonCtrl.ini
COPY --from=edcb-builder /var/local/edcb/ContentTypeText.txt /var/local/edcb/ContentTypeText.txt
COPY --from=edcb-builder /src/edcb/ini/HttpPublic /var/local/edcb/HttpPublic
RUN chown -R edcb:edcb /var/local/edcb

RUN ln -s /usr/local/lib/edcb/BonDriver_LinuxMirakc.so /var/local/edcb/BonDriver/

COPY docker/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/var/local/edcb", "/recordings"]

# TCP API port and HTTP port
EXPOSE 4510 5510

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD ["/usr/local/bin/healthcheck.sh"]

WORKDIR /var/local/edcb

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["/usr/local/bin/EpgTimerSrv"]

# =============================================================================
# Stage 5: Runtime with EDCB Material WebUI
# =============================================================================
FROM runtime AS runtime-emwui

COPY --from=emwui-src /src/emwui/HttpPublic/EMWUI/ /var/local/edcb/HttpPublic/EMWUI/
COPY --from=emwui-src /src/emwui/HttpPublic/api/ /var/local/edcb/HttpPublic/api/
COPY --from=emwui-src /src/emwui/Setting/HttpPublic.ini /var/local/edcb/HttpPublic.ini.default
COPY --from=emwui-src /src/emwui/Setting/XCODE_OPTIONS.lua /var/local/edcb/XCODE_OPTIONS.lua.default

RUN chown -R edcb:edcb /var/local/edcb/HttpPublic/EMWUI/ \
    /var/local/edcb/HttpPublic/api/ \
    /var/local/edcb/HttpPublic.ini.default \
    /var/local/edcb/XCODE_OPTIONS.lua.default
