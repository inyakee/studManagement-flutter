FROM mcr.microsoft.com/devcontainers/base:bookworm
ARG FLUTTER_VERSION=3.47.2
USER root
RUN apt-get update && apt-get install -y --no-install-recommends curl git unzip xz-utils zip libglu1-mesa python3 ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter \
    && chown -R vscode:vscode /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
USER vscode
RUN flutter config --enable-web --no-analytics && flutter precache --web
