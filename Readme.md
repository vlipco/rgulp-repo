Vlipco's gulp-repo
===========

This a gulp repo used to build multiple Vlipco front-end apps.

## Environment dependencies

- npm >= 1.4.3
- node >= v0.10.26
- ruby >= 2.0.0
- bundler >= 1.4.0.rc.1

Has been tested with npm v1.4.3 & node v0.10.26

## Preparing your environment

1. Make sure all env dependencies are satisfied.
3. If you are on osx `brew install pngquant pngcrush` for [assetgraph-builder](https://github.com/assetgraph/assetgraph-builder) for other platforms, check the repo.
3. Install gulp globally with `npm install gulp -g`
3. Install Rgulp globally with `npm install rgulp -g`

## Including in a project

Once you have your environment with all dependencies, you simply include an RGfile.coffee (or RGfile.js) at the root of your project.

This tells Rgulp how to get this repo and apply if to your repo, this is a sample of what it should look like:

```coffeescript
repo_data = src: 'git@github.com:Vlipco/rgulp-repo.git', checkout: 'master'
module.exports = source: repo_data
```

It says that the gulp repo to use is this git repo checked out at the master branch.

After adding this, simply run `rgulp prepare` in your project (this can take some minutes, be patient) and this will:

1. Clone this repo into .rgulp folder
2. Run the prepare script that install the ruby & node dependencies.

Then just run `rgulp -T` to see all the tasks you have available.

## Misc. notes

This gulpgile accepts --type production/deployment to trigger target specific settings

Potential improvements:

- Make the sourcemaps work correctly.
- Plumber to prevent errors
- Deploy with ansible
- watch for changes in build & remake compressed version
- caching
- receive configuration variables, e.g. CDN url

The NVM_DIR ENV variable is needed to run.

Selenium standalone server downloaded from: http://selenium-release.storage.googleapis.com/index.html?path=2.40/ into `test/vendor`