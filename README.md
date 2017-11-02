# heroku-nodejs-build

Scripts to help build, package, release and deploy node apps to Heroku

## Installation

    yarn add --dev heroku-nodejs-build

## Requirements

* [Docker](https://www.docker.com/) installed
* [Yarn](https://yarnpkg.com) installed
* A script to build and test your application located at `scripts/verify`

## Usage

In `package.json` add the following scripts

``` json
  "scripts": {
    "verify": "scripts/verify",
    "package": "node_modules/heroku-nodejs-build/scripts/package",
    "release": "node_modules/heroku-nodejs-build/scripts/release",
    "deploy": "node_modules/heroku-nodejs-build/scripts/deploy"
  }
```

### To release a new version of your app run

    yarn run package && \
    GITHUB_REPO=your/github-repo \
    GITHUB_TOKEN=your-github-token \
    yarn run release

Get a github token [here](https://github.com/settings/tokens)

### To deploy a version of your app run

    RELEASE_TAG=the-tag or "latest" \
    GITHUB_REPO=your/github-repo \
    GITHUB_TOKEN=your-github-token \
    HEROKU_APP=your-heroku-app \
    HEROKU_TOKEN=your-heroku-token \
    yarn run release

Get a heroku token with `heroku auth:token`
