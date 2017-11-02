#!/usr/bin/env node

const {ARTIFACT_NAME, log, error, github, run} = require('./helpers');
const repo = process.env.GITHUB_REPO;

(function main() {
  verifyCleanWorkingDirectory();

  if (releaseNeeded()) {
    let release = createRelease();
    uploadAssets(release);
    github.get(repo, `releases/tags/${release.tag_name}`, 'build/release.json');
  } else {
    log('this package has already been released');
  }
})();

function verifyCleanWorkingDirectory() {
  let resp = run('git', 'status', '--porcelain').stdout.toString();
  if (resp) error(`Workspace is not clean. You'll need to commit any changes so we can tag this release.\n\nOutstanding changes:\n${resp}`);
}

function createRelease() {
  let tag = tagReleaseWith(nextTag());
  return github.post(repo, 'releases', {'tag_name': tag.ref.split('/').pop(), 'target_commitish': tag.object.sha}).json;
}

function tagReleaseWith(tag) {
  let sha = run('git', 'rev-parse', 'HEAD').stdout.toString().trim();
  log(`tagging ${sha} with ${tag}`);
  return github.post(repo, 'git/refs', {ref: `refs/tags/${tag}`, sha}).json;
}

function nextTag() {
  let currentTagNumber = 0;
  log('looking for the last published release');

  try {
    let currentTag = github.get(repo, 'releases/latest').json.tag_name;
    currentTagNumber = parseInt(('' + currentTag).replace(/\D/g, '')) || 0;
  } catch (e) {
    if (!isNotFound(e)) throw (e);
  }

  return `v${currentTagNumber + 1}`;
}

function isNotFound(e) {
  return e.message.match(/status: 404/);
}

function uploadAssets(release) {
  run('tar', '-cvzf', `build/${ARTIFACT_NAME}.tar.gz`, '--exclude', `${ARTIFACT_NAME}.tar.gz`, '-C', 'build', '.');
  log('uploading artifacts...');
  github.upload(repo, `${release.upload_url.replace(/{.*}/, '')}?name=${ARTIFACT_NAME}.tar.gz&label=${ARTIFACT_NAME}`, 'application/x-gzip', `build/${ARTIFACT_NAME}.tar.gz`);
  return github.upload(repo, `${release.upload_url.replace(/{.*}/, '')}?name=${ARTIFACT_NAME}.md5&label=${ARTIFACT_NAME}.md5`, 'text/plain', 'build/slug.md5');
}

function releaseNeeded() {
  try {
    let lastReleaseChecksum = getCurrentChecksum();
    let newReleaseChecksum = run('cat', 'build/slug.md5').stdout.toString().trim();
    log(`last release checksum: ${lastReleaseChecksum}, this release checksum: ${newReleaseChecksum}`);
    return lastReleaseChecksum !== newReleaseChecksum;
  } catch (e) {
    if (isNotFound(e)) return true;
    throw (e);
  }
}

function getCurrentChecksum() {
  let latestRelease = github.get(repo, 'releases/latest').json;
  let checksumAsset = latestRelease.assets.find((asset) => asset.name === `${ARTIFACT_NAME}.md5`);
  if (!checksumAsset) return false;
  return run('cat', github.download(repo, checksumAsset.url)).stdout.toString().trim();
}
