# syntax=docker/dockerfile:1
ARG DEBIAN_RELEASE=oldoldstable

FROM debian:$DEBIAN_RELEASE AS build-stage
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      git ca-certificates wget patchelf build-essential libudev-dev libevdev-dev zlib1g-dev gvfs valac libgee-0.8-dev meson

COPY . /

ARG BUILD_TYPE=release
ARG ENABLE_LTO=true
ARG TARGETOS TARGETARCH TARGETVARIANT
ARG OWNER=v1993
ARG VERSION=v0.0.0-unknown

RUN meson setup \
      --fatal-meson-warnings \
      "--buildtype=${BUILD_TYPE}" \
      "-Db_lto=${ENABLE_LTO}" \
      --prefix=/usr \
      /build && \
    meson compile -C /build && \
    meson install --destdir=/ -C /build

RUN <<EOF
  set -eu
  arch="$(uname -m)"

  export DESKTOP=./dist/evdevhook2.desktop
  export ICON=./dist/evdevhook2.png
  export OUTNAME="evdevhook2-${VERSION}-${arch}.AppImage"
  export OUTPATH=/appimage
  export UPINFO="gh-releases-zsync|${OWNER}|evdevhook2|latest|evdevhook2-*-${arch}.AppImage.zsync"
  export VERSION

  sharun="https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/quick-sharun.sh"
  wget "${sharun}" -O- | install /dev/stdin ./quick-sharun.sh
  ./quick-sharun.sh /usr/bin/evdevhook2
  ./quick-sharun.sh --make-appimage
EOF

FROM scratch AS export-stage
COPY --from=build-stage /appimage/* /
