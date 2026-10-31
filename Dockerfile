# syntax=docker/dockerfile:1
FROM ghcr.io/pkgforge-dev/archlinux AS build-stage

# Install dependencies
RUN <<EOF
  pacman -Syu --noconfirm meson base-devel vala git libgee libevdev
EOF

# Build application
COPY . /
ARG BUILD_TYPE=release
ARG ENABLE_LTO=true
ARG TARGETOS TARGETARCH TARGETVARIANT
RUN <<EOF
  set -eu
  meson setup \
      --fatal-meson-warnings \
      "--buildtype=${BUILD_TYPE}" \
      "-Db_lto=${ENABLE_LTO}" \
      --prefix=/usr \
      /build
  meson compile -C /build
  meson install --destdir=/ -C /build
EOF

# Basic test for broken binary
ARG APP_NAME=evdevhook2
RUN <<EOF
  timeout 5 "/usr/bin/${APP_NAME}"
  rc="$?"
  if [ "$rc" -ne 124 ]; then
    echo >&2 "Application returned unexpected code $rc."
    if [ "$rc" -ne 0 ]; then exit "$rc"; else exit 1; fi
  fi
EOF

# Build AppImage
ARG OWNER=owner
ARG VERSION=v0.0.0-unknown
RUN <<EOF
  set -eu
  pacman -Syu --noconfirm patchelf xorg-server-xvfb
  arch="$(uname -m)"

  export DESKTOP="dist/${APP_NAME}.desktop"
  export ICON="dist/${APP_NAME}.png"
  export OUTNAME="${APP_NAME}-${VERSION}-${arch}.AppImage"
  export OUTPATH=/appimage
  export UPINFO="gh-releases-zsync|${OWNER}|${APP_NAME}|latest|${APP_NAME}-*-${arch}.AppImage.zsync"
  export VERSION

  sharun="https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/quick-sharun.sh"
  curl -fsSL "${sharun}" | install /dev/stdin ./quick-sharun.sh
  ./quick-sharun.sh "/usr/bin/${APP_NAME}"
  ./quick-sharun.sh --make-appimage
EOF

FROM scratch AS export-stage
COPY --from=build-stage /appimage/* /
