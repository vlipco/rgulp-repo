gulp = require 'gulp'
gutil = require 'gulp-util'
rg = require('../rgulp/rgulp.coffee')(silent: false, root: gutil.env.root)

process.chdir rg.root

runSequence = require 'run-sequence'

jade = require 'gulp-jade'
sass = require 'gulp-ruby-sass'
coffee = require 'gulp-coffee'
include = require 'gulp-include'
clean = require 'gulp-clean'
gulpif = require 'gulp-if'
using = require 'gulp-using'
lazypipe = require 'lazypipe'

#watch = require('gulp-watch')
plumber = require 'gulp-plumber'

reduce = require 'gulp-reduce'

removeLogs = require 'gulp-removelogs'

glob = require 'glob'
pretty = require 'pretty-bytes'
server = require 'pushstate-server'

# we determine the targets relative to the root of the project
# managed by Rgulp
target = './build/dev'
minTarget = './build/min'
distTarget = './build/dist' # CDNized for deployment

cloudfront = "//lvh.me:3000"

PRODUCTION = 'production'
DEPLOYMENT = 'deployment'

isProduction = -> gutil.env.type == PRODUCTION
isDeployment = -> gutil.env.type == DEPLOYMENT
shouldCompress = -> isProduction() || isDeployment()
withCompression = (f) -> gulpif shouldCompress(), f

typeTarget = ->
	switch gutil.env.type
		when PRODUCTION then minTarget
		when DEPLOYMENT then distTarget
		else target

# considered static by the push state server
assetsExtensions = "+(svg|eot|ttf|woff|gif|png)"

assetsGlob = "app/**/*.#{assetsExtensions}"
jadeGlob = 'app/index.jade'

coffeeGlob = ['app/javascripts/*.coffee','!**/_*.coffee']
sassGlob = ['app/**/*.sass','!**/_*.sass']

gulp.task 'clean', -> 
	gulp.src([target,minTarget,distTarget], {read: false}).pipe clean()

gulp.task 'copy', ->
	gulp.src(assetsGlob).pipe gulp.dest target

gulp.task 'jade', ->
	gulp.src jadeGlob
		.pipe include()
		.pipe jade()		
		.pipe gulp.dest target

gulp.task 'coffee', ->
	dest = "#{target}/javascripts"
	gulp.src coffeeGlob
		.pipe include()
		.pipe coffee sourceMap: !shouldCompress()
		.pipe withCompression removeLogs()
		.pipe gulp.dest dest

gulp.task 'sass', ->
	dest = "#{target}/stylesheets"
	gulp.src sassGlob
		.pipe sass loadPath: ['app/stylesheets', 'app/vendor']	
		.pipe gulp.dest dest

gulp.task 'relocate-cdn-assets', (cb)->
	gutil.log "/static/cdn/* -> /static/*" # overrides asset-graph default
	defaultFolder = "#{distTarget}/static/cdn"
	gulp.src("#{defaultFolder}/**/*.*").pipe gulp.dest "#{distTarget}/static"
	gulp.src("#{defaultFolder}/").pipe clean()

gulp.task 'compress', (cb)->
	common = "--root #{target} --gzip"
	if isDeployment()
		gutil.log "Using #{cloudfront} as CDN"
		options = "#{common} --outroot #{distTarget} --cdnroot #{cloudfront}/static"	
	else
		options = "#{common} --outroot #{minTarget}"	

	cmd = "buildProduction #{options} #{target}/index.html"
	exec = require('child_process').exec
	exec cmd, (err, stdout, stderr)-> gutil.log stderr if err ; cb(err)
		
gulp.task 'build', ['clean'], (cb)->
	args = [['jade', 'coffee','sass','copy']]
	if shouldCompress()
		args.push 'compress'
		args.push 'size-diff'
	args.push 'relocate-cdn-assets' if isDeployment()
	args.push(cb)
	runSequence.apply this, args

gulp.task 'size-diff', (cb)->
	unless shouldCompress()
		throw "This task can only be run with --type [production|deployment]"
	
	fs = require("fs")
	pattern = "**/*.+(html|js|css|svg)"
	pre = "#{target}/#{pattern}"
	post = "#{typeTarget()}/#{pattern}.gz"

	gutil.log 
	sumFiles = (files)->
		totalSize = 0
		totalSize += fs.statSync(file).size for file in files
		return totalSize
	
	beforeFiles = glob.sync(pre)
	beforeSize = sumFiles beforeFiles
	afterFiles = glob.sync(post)
	afterSize = sumFiles afterFiles
	absDiff = beforeSize - afterSize
	relDiff = Math.round absDiff/beforeSize*100
	
	gutil.log "Gzip yielded a",
		gutil.colors.cyan("#{relDiff}% reduction")

	gutil.log "#{pretty beforeSize} to #{pretty afterSize}",
		"(#{target} -> #{typeTarget()})"

gulp.task 'start-watchers', ->
	customWatch = (glob,deps)->
		gulp.watch(glob, deps).on 'change', (e)->
			gutil.log "File",
				gutil.colors.magenta(e.path),
				"#{e.type} running",
				gutil.colors.cyan(deps)

	gutil.log "Creating watchers, be patient."
	customWatch assetsGlob, ['copy']
	customWatch jadeGlob, ['jade']
	customWatch coffeeGlob, ['coffee']
	customWatch sassGlob, ['sass']

gulp.task 'start-server', ->
	gutil.log "Serving #{typeTarget()}"

	server.start port: 3000, directory: typeTarget()

gulp.task 'dev', (cb)->
	runSequence 'build', ['start-server','start-watchers'], cb