#!/usr/bin/env node

const path = require('path');
const {ARTIFACT_NAME, log, error, notify, env, github, heroku, run} = require('./helpers');
const repo = process.env.GITHUB_REPO;
const application = process.env.HEROKU_APP;

(function main() {
  const releaseTag = getReleaseTagToDeploy();
  const release = getReleaseToDeploy(releaseTag);
  const releaseLink = `<https://github.com/${repo}/compare/${previousReleaseTag(releaseTag)}...${releaseTag}|${releaseTag}>`;
  const appLink = `<https://${application}.herokuapp.com|${application}>`;

  log(`deploying ${releaseTag} to ${application}`);

  try {
    let artifact = downloadBuildArtifact(release.assets);
    let artifactsDir = untarArtifact(artifact);
    log('creating new slug');
    let slug = heroku.post(`${application}/slugs`, {'process_types': {web: 'cd /app/user && yarn run start'}}).json;
    log('uploading slug');
    heroku.upload(slug.blob.method, slug.blob.url, `${artifactsDir}/slug.tgz`);
    log('releasing slug');
    heroku.post(`${application}/releases`, {slug: slug.id});
    log('updating config');
    heroku.patch(`${application}/config-vars`, {'RELEASE_TAG': releaseTag});
    notify(`deployed ${releaseLink} to ${appLink}`);
  } catch (e) {
    notify(`deployment of ${releaseLink} to ${appLink} failed - ${e.message}`);
    throw e;
  }
})();

function getReleaseTagToDeploy() {
  return env('RELEASE_TAG') === 'latest' ? github.get(repo, 'releases/latest').json.tag_name : env('RELEASE_TAG');
}

function previousReleaseTag(tag) {
  return tag.replace(/\d+/, (match) => parseInt(match) - 1);
}

function getReleaseToDeploy(tag) {
  try {
    return github.get(repo, `releases/tags/${tag}`).json;
  } catch (e) {
    error(`unable to get release "${tag}" from github -- ${e.message}`);
  }
}

function downloadBuildArtifact(assets = []) {
  let artifact = assets.find((asset) => asset.label === ARTIFACT_NAME);

  if (artifact) {
    log(`downloading ${artifact.url}`);
    return github.download(repo, artifact.url);
  } else {
    throw new Error(`Unable to find an artifact labeled ${ARTIFACT_NAME}`);
  }
}

function untarArtifact(artifact) {
  let dir = path.dirname(artifact);
  run('tar', '-xvzf', artifact, '-C', dir);
  return dir;
}
