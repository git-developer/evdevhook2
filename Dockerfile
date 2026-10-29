# syntax=docker/dockerfile:1
ARG UBUNTU_RELEASE=jammy

FROM ubuntu:$UBUNTU_RELEASE AS build-stage
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      git ca-certificates wget patchelf build-essential libudev-dev libevdev-dev zlib1g-dev valac libgee-0.8-dev meson

COPY . /

ARG BUILD_TYPE=release
ARG ENABLE_LTO=true
ARG TARGETOS TARGETARCH TARGETVARIANT
ARG VERSION OWNER

RUN meson setup \
      --fatal-meson-warnings \
      "--buildtype=${BUILD_TYPE}" \
      "-Db_lto=${ENABLE_LTO}" \
      --prefix=/usr \
      /build && \
    meson compile -C /build && \
    meson install --destdir=/release -C /build

RUN <<EOF
  set -eu

  export DESKTOP=./dist/evdevhook2.desktop
  export ICON=./dist/evdevhook2.png
  export OUTPATH=/appimage
  export UPINFO="gh-releases-zsync|${OWNER}|evdevhook2|latest|evdevhook2-*-$(uname -m).AppImage.zsync"
  export VERSION="${VERSION:-0.0.0-unknown}"

  sharun="https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/quick-sharun.sh"
  wget "${sharun}" -O- | install /dev/stdin ./quick-sharun.sh
  ./quick-sharun.sh /release/usr/bin/evdevhook2
  ./quick-sharun.sh --make-appimage
EOF

FROM scratch AS export-stage
COPY --from=build-stage /appimage/* /
