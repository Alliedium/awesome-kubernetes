#!/bin/sh
# Build Docker image for k3s
#
# Usage:
#   ./build-k3s.sh [<k3s-version>]
#
# if k3s-version is not given, the latest available version will be used
#
set -e

GITHUB_URL=https://github.com/k3s-io/k3s/releases
LATEST_VERSION=$(curl -w '%{url_effective}' -I -L -s -S ${GITHUB_URL}/latest -o /dev/null | sed -e 's|.*/||')
VERSION_TO_BUILD="${1:-${LATEST_VERSION}}"
ALPINE_VERSION=$(curl  -L -s -S https://raw.githubusercontent.com/k3s-io/k3s/${VERSION_TO_BUILD}/package/Dockerfile | grep 'FROM alpine:' | cut -d ' ' -f 2)
K3S_VERSION=$(echo ${VERSION_TO_BUILD} | sed -e 's|\+|-|')
IMAGE_TAG="k3s:${K3S_VERSION}-${ALPINE_VERSION/:/-}"
if docker image inspect ${IMAGE_TAG} > /dev/null 2> /dev/null; then
  echo "Image ${IMAGE_TAG} already exists, skip building"
else
 echo "Building k3s ${VERSION_TO_BUILD} as ${IMAGE_TAG} (from rancher/k3s:${VERSION_TO_BUILD})"
  docker build -t ${IMAGE_TAG} --file Dockerfile-k3s --build-arg=ALPINE_VERSION=${ALPINE_VERSION} --build-arg=K3S_VERSION=${K3S_VERSION} .
fi
echo ${IMAGE_TAG}