const fs = require('fs');
const childProcess = require('child_process');

const GITHUB_BASE_URL = 'https://api.github.com/repos';
const HEROKU_BASE_URL = 'https://api.heroku.com/apps';

module.exports = {
  ARTIFACT_NAME: 'web-bundle',
  log,
  debug,
  error,
  notify,
  env,
  run,
  github: {
    get: githubGet,
    post: githubPost,
    upload: githubUpload,
    download: githubDownload
  },
  heroku: {
    post: herokuPost,
    patch: herokuPatch,
    upload: herokuUpload
  }
};

function log(message) {
  console.log(`[heroku-nodejs-build] ${message}`);
}

function debug(message) {
  if (process.env.VERBOSE) log(message);
}

function error(message) {
  throw new Error(message);
}

function notify(message) {
  log(message);
  if (!process.env.SLACK_URL) return;
  curl('-X', 'POST', '--data-urlencode', `payload=${JSON.stringify({text: message})}`, env('SLACK_URL'));
}

function env(key) {
  let value = process.env[key];
  if (!value) error(`${key} must be set`);
  return value;
}

function run(cmd, ...args) {
  return childProcess.spawnSync(cmd, args);
}

function githubGet(repo, endpoint, toFile) {
  let args = [githubUrl(repo, endpoint)];
  if (toFile) args.unshift('-o', toFile);
  return githubCurl(...args);
}

function githubPost(repo, endpoint, body) {
  return githubCurl('-H', 'Content-Type: application/json', '-X', 'POST', '-d', JSON.stringify(body), githubUrl(repo, endpoint));
}

function githubUpload(repo, endpoint, type, file) {
  return githubCurl('-H', `Content-Type: ${type}`, '-X', 'POST', '--data-binary', `@${file}`, githubUrl(repo, endpoint));
}

function githubDownload(repo, endpoint) {
  let tempdir = fs.mkdtempSync('/tmp/heroku-nodejs-build-');
  let tempfile = `${tempdir}/download`;

  run(
    'curl',
    '-v',
    '-L',
    '-H',
    'Accept: application/octet-stream',
    '-H',
    `Authorization: token ${env('GITHUB_TOKEN')}`,
    '-o',
    tempfile,
    githubUrl(endpoint)
  );

  return tempfile;
}

function githubUrl(repo, endpoint) {
  return endpoint.startsWith('http') ? endpoint : `${GITHUB_BASE_URL}/${repo}/${endpoint}`;
}

function githubCurl(...args) {
  args.unshift('-H', `Authorization: token ${env('GITHUB_TOKEN')}`);
  return curl(...args);
}

function herokuPost(endpoint, body) {
  return herokuCurl('-H', 'Content-Type: application/json', '-X', 'POST', '-d', JSON.stringify(body), herokuUrl(endpoint));
}

function herokuPatch(endpoint, body) {
  return herokuCurl('-H', 'Content-Type: application/json', '-X', 'PATCH', '-d', JSON.stringify(body), herokuUrl(endpoint));
}

function herokuUpload(method, endpoint, file) {
  return curl('-X', method.toUpperCase(), '-H', 'Content-Type:', '--data-binary', `@${file}`, herokuUrl(endpoint));
}

function herokuUrl(endpoint) {
  return endpoint.startsWith('http') ? endpoint : `${HEROKU_BASE_URL}/${endpoint}`;
}

function herokuCurl(...args) {
  args.unshift('-H', 'Accept: application/vnd.heroku+json; version=3', '-H', `Authorization: Bearer ${env('HEROKU_TOKEN')}`);
  return curl(...args);
}

function curl(...args) {
  args.unshift('-v', '-L', '-w', '%{http_code}');
  let resp = run('curl', ...args);
  let status = resp.stdout.toString().match(/(\d{3})$/)[1];
  let json = resp.stdout.toString().replace(/\d{3}$/, '');
  debug(resp.stderr.toString());

  try {
    resp.json = JSON.parse(json);
  } catch (e) {
    //ignore non json responses
  }

  if (!status.match(/2\d\d/)) error(`status: ${status}, response: ${json}`);
  return resp;
}
