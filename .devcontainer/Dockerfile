FROM mcr.microsoft.com/devcontainers/base:ubuntu

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl unzip ca-certificates \
        libx11-6 libxrandr2 libxinerama1 libxcursor1 libxi6 \
        libgl1 libegl1 libfontconfig1 libssl3 \
        xvfb \
    && rm -rf /var/lib/apt/lists/*

ARG GODOT_VERSION=4.7.2-stable
RUN mkdir -p /opt/godot \
    && curl -fSL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" \
    && unzip -q /tmp/godot.zip -d /opt/godot \
    && rm /tmp/godot.zip \
    && ln -s /opt/godot/Godot_v${GODOT_VERSION}_linux.x86_64 /usr/local/bin/godot \
    && godot --version
