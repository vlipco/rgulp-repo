gulp = require 'gulp'
gutil = require 'gulp-util'
rg = require('rgulp')(silent: false, root: gutil.env.root)

process.chdir rg.root

runSequence = require 'run-sequence'

jade = require 'gulp-jade'
sass = require 'gulp-ruby-sass'
coffee = require 'gulp-coffee'
include = require 'gulp-include'
templateCache = require 'gulp-angular-templatecache'
clean = require 'gulp-clean'
gulpif = require 'gulp-if'
using = require 'gulp-using'
lazypipe = require 'lazypipe'
cson = require 'gulp-cson'
tap = require 'gulp-tap'
#watch = require('gulp-watch')
plumber = require 'gulp-plumber'
reduce = require 'gulp-reduce'

removeLogs = require 'gulp-removelogs'

glob = require 'glob'
pretty = require 'pretty-bytes'
server = require 'pushstate-server'
_ = require 'underscore'

karma = require 'gulp-karma'
protractor = require 'gulp-protractor'
# we determine the targets relative to the root of the project
# managed by Rgulp
target = rg.expand 'build/dev'
minTarget = rg.expand 'build/min'
distTarget = rg.expand 'build/dist' # CDNized for deployment

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

assetsGlob = rg.expand "app/**/*.#{assetsExtensions}"
jadeGlob = rg.expand "app/index.jade"

coffeeWatchGlob = [
	rg.expand('app/src/*.coffee')
	rg.expand('app/src/**/*.coffee')
	rg.expand('app/vendor/*.coffee')
]
coffeeCompileGlob = [
	rg.expand('app/src/*.coffee')
	rg.expand('app/src/**/*.coffee')
	"!#{rg.expand('!**/_*.coffee')}"
]

coffeeTestCompileGlob = [
	rg.expand('test/spec/*.coffee')
	rg.expand('test/spec/**/*.coffee')
]

coffeeE2ETestCompileGlob = [
	rg.expand('test/e2e/*.coffee')
	rg.expand('test/e2e/**/*.coffee')
]

dependenciesGlob = [
	rg.expand('app/vendor/*.js')
]
testDependenciesGlob=[
	rg.expand('test/vendor/*.js')
]

sassWatchGlob = [rg.expand('app/**/*.sass')]
sassCompileGlob = [
		rg.expand('app/**/*.sass')
		"!#{rg.expand('!**/_*.sass')}"
	]

csonGlob = [
	rg.expand('app/data/*.cson')
	rg.expand('app/data/**/*.cson')
]

templateGlob = [
	rg.expand('app/src/*.jade')
	rg.expand('app/src/**/*.jade')
]

template_temps = "#{target}/.tmp/templates"
htmlGlob = [
	rg.expand("#{template_temps}/*.html")
	rg.expand("#{template_temps}/**/*.html")
]

test_temps = "#{target}/test"

compiledTestGlob = [
	rg.expand("#{test_temps}/**/*.js")
]

completeTestGlob = _.union [
		rg.expand("#{target}/js/dependencies.js")
		rg.expand("#{target}/js/templates.js")
		rg.expand("#{target}/js/app.js")
		rg.expand("#{target}/test/test_dependencies.js")
	]
	,compiledTestGlob

gulp.task 'clean', -> 
	gulp.src([target,minTarget,distTarget], {read: false}).pipe clean(force: true)

gulp.task 'copy', ->
	gulp.src(assetsGlob)
		.pipe gulp.dest target

gulp.task 'jade', ->
	gulp.src jadeGlob
		.pipe include()
		.pipe jade()
		.pipe gulp.dest target

gulp.task 'coffee', ->
	dest = "#{target}/js"
	gulp.src coffeeCompileGlob
		.pipe include({extensions: "coffee"})
		.pipe coffee()
		# .pipe coffee({sourceMap: !shouldCompress()})
		.pipe withCompression removeLogs()
		.pipe gulp.dest dest


gulp.task 'js', ->
	dest = "#{target}/js"
	gulp.src dependenciesGlob
		.pipe include({extensions: "js"})
		.pipe gulp.dest dest
	# dest =

gulp.task 'js-test', ->
	dest = "#{target}/test"
	gulp.src testDependenciesGlob
		.pipe include({extensions: "js"})
		.pipe gulp.dest dest

gulp.task 'sass', ->
	dest = "#{target}/css"
	gulp.src sassCompileGlob
		#Stylesheets load path
		.pipe sass
			loadPath: [rg.expand('app/stylesheets'), rg.expand('app/vendor')]
			# sourcemap: !shouldCompress()
			quiet: true
		.pipe gulp.dest dest

gulp.task 'cson', ->
	dest = "#{target}/data"
	gulp.src csonGlob
		.pipe cson()
		.pipe gulp.dest dest

gulp.task 'compile-templates', ->
	gulp.src templateGlob
		.pipe jade()
		.pipe gulp.dest template_temps

gulp.task 'jsfy-templates', ->
	dest = "#{target}/js"

	gulp.src htmlGlob
		.pipe templateCache( null ,{standalone: true}, (name)->
			name.split(".html")[0]
		)
		.pipe gulp.dest dest

gulp.task 'inject-templates', (cb) ->
	runSequence 'compile-templates', 'jsfy-templates', cb

###
TESTING
###
gulp.task 'coffee-test', ->
	dest = "#{target}/test"
	gulp.src coffeeTestCompileGlob
		.pipe include({extensions: "coffee"})
		.pipe coffee()
		# .pipe coffee({sourceMap: !shouldCompress()})
		.pipe withCompression removeLogs()
		.pipe gulp.dest dest


gulp.task 'karma-watch', ->
	gulp.src completeTestGlob
		.pipe karma( configFile: '../test/config/karma.conf.coffee', action: "watch")
		#The watch function is managed by the gulp watchers.
gulp.task 'karma', ->
	gulp.src completeTestGlob
		.pipe karma( configFile: '../test/config/karma.conf.coffee', action: "run")
		#The watch function is managed by the gulp watchers.

gulp.task 'e2e', ->
	gulp.src coffeeE2ETestCompileGlob
		.pipe protractor.protractor(configFile: '../test/config/protractor.conf.coffee')

###
###
gulp.task 'relocate-cdn-assets', (cb)->
	gutil.log "/static/cdn/* -> /static/*" # overrides asset-graph default
	defaultFolder = "#{distTarget}/static/cdn"
	gulp.src("#{defaultFolder}/**/*.*").pipe gulp.dest "#{distTarget}/static"
	gulp.src("#{defaultFolder}/").pipe clean()


gulp.task 'compress', (cb)->
	common = "--root #{target} --gzip"
	console.log "common: ", common
	if isDeployment()
		gutil.log "Using #{cloudfront} as CDN"
		options = "#{common} --outroot #{distTarget} --cdnroot #{cloudfront}/static"	
	else
		options = "#{common} --outroot #{minTarget}"
		console.log "options:", options

	cmd = "buildProduction #{options} #{target}/index.html"
	console.log "cmd:", cmd
	exec = require('child_process').exec
	exec cmd, (err, stdout, stderr)-> gutil.log stderr if err ; cb(err)
		
gulp.task 'build', ['clean'], (cb)->
	args = [['jade', 'coffee', 'js', 'inject-templates', 'sass', 'copy']]
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
	customWatch coffeeWatchGlob, ['coffee']
	customWatch dependenciesGlob, ['js']
	customWatch sassWatchGlob, ['sass']
	customWatch templateGlob, ['inject-templates']
	customWatch coffeeTestCompileGlob, ['coffee-test']
	# customWatch coffeeE2ETestCompileGlob, ['e2e']

gulp.task 'start-server', ->
	gutil.log "Serving #{typeTarget()}"

	server.start port: 3000, directory: typeTarget()

gulp.task 'dev', (cb)->
	runSequence 'build', ['test', 'start-server','start-watchers'], cb

gulp.task 'test', (cb)->
	runSequence 'coffee-test', 'js-test', ['karma-watch'], cb