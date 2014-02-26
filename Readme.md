Vlipco's gulp-repo
===========

TODO: pending update by DPT!!

## Environment dependencies

- npm >= 1.3.11
- node >= v0.10.21
- ruby >= 2.0.0
- bundler >= 1.4.0.rc.1

## To develop locally

1. Clone locally.
2. Make sure you have all the dependencies installed.
3. If you are on osx `brew install pngquant pngcrush` for [assetgraph-builder](https://github.com/assetgraph/assetgraph-builder) for other platforms, check the repo.
3. Install gulp globally with `npm install gulp -g`
2. Install the app's repo's dev dependencies for ruby & node with `npm install && bundle`
3. Run `gulp dev` and it'll compile and start the server in localhost:3000

## Misc. notes

You can see a list of all the available tasks with `gulp -T`

Use --type production/deployment to trigger target specific settings

alias rgulp="./rgulp/bin/rgulp"

Working with npm v1.4.3 & node v0.10.26