#!/bin/bash

ROOT_DIR="$(cd .. && pwd)"
APP_DIR="$(pwd)"
TEMP_ROOT_DIR="/tmp/heroku-nodejs-build-$(date +%Y%m%d_%H%M%S)"
TEMP_APP_DIR="${TEMP_ROOT_DIR}${APP_DIR}"
rm -rf "${TEMP_ROOT_DIR}" && mkdir -p "${TEMP_ROOT_DIR}"
GIT_SHA="$(git rev-parse HEAD)"

# -----------------------------------------------------------------------------
# This copies everything needed to do a build to a temporary directory
# in the container as to not disturb the source (node_modules in particular)
# on the host
# -----------------------------------------------------------------------------
rsync -a \
  --exclude=".DS_Store" \
  --exclude="phantomjs" \
  --exclude=".gnupg" \
  --exclude=".jdk" \
  --exclude=".m2" \
  --exclude=".maven" \
  --exclude=".npm" \
  --exclude="${APP_DIR}/.git/" \
  --exclude="${APP_DIR}/node_modules/" \
  "${ROOT_DIR}" "${TEMP_ROOT_DIR}"

cd "${TEMP_APP_DIR}" || exit
sed -i -e "s/\[GIT_SHA\]/${GIT_SHA}/g" server/config/version.js

# -----------------------------------------------------------------------------
# Creates a checksum for the slug so we don't have to publish a new release
# if nothing has changed. i.e. just a documentation or README change. We
# ignore node_modules since yarn.lock should take care of this and version.js
# since that changes with every build.
# -----------------------------------------------------------------------------
function fingerprint {
  mkdir -p "${TEMP_ROOT_DIR}/fingerprint" && \
  tar xzf build/slug.tgz -C "${TEMP_ROOT_DIR}/fingerprint" && \
  cd "${TEMP_ROOT_DIR}/fingerprint${APP_DIR}" && \
  find . -type f ! -path "*node_modules*" ! -path "*server/config/version.js" -exec md5sum {} \; \
    | sort -k 2 \
    | tee "${TEMP_APP_DIR}/build/slug.txt" \
    | md5sum \
    | cut -d ' ' -f 1 > "${TEMP_APP_DIR}/build/slug.md5"
}

# -----------------------------------------------------------------------------
# Builds the heroku slug ignoring stuff that's not needed for production to
# keep the artifact size down
# -----------------------------------------------------------------------------
function package {
  echo "removing dev dependencies..." && yarn install --production && \
  echo "building the slug..." && touch .slugignore && tar cfz build/slug.tgz -C "${TEMP_ROOT_DIR}" -X .slugignore . && \
  echo "generating the slug checksum..." && fingerprint && echo "${TEMP_APP_DIR}/build/slug.md5"
}

# -----------------------------------------------------------------------------
# Run verify from the temp directory, build the slug, store the return code and
# and move build artifacts from the temp directory back to the host so we can
# do something with them after this container goes away
# -----------------------------------------------------------------------------
./scripts/verify && package

BUILD_RESULT=$?

rm -rf "${APP_DIR}/build" && mv "${TEMP_APP_DIR}/build" "${APP_DIR}"
mkdir -p "${APP_DIR}/build/maps" && cp "${TEMP_APP_DIR}"/server/public/*.map "${APP_DIR}/build/maps"

exit $BUILD_RESULT
