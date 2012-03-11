Railgun guides your client-side app from development to production. Bundles and optimizes your assets. Separates dev and production environment. Simplifies working with public and private CDNs.

Railgun has five basic features.

* Packages up a client-side app for easy distribution through a CDN or faster serving on your own hardware: minification, concatenation, all that good stuff.
* Preprocesses template languages into HTML, CoffeeScript into JavaScript and stylesheet languages into CSS.
* Filters out code you only need during development and includes code you only need in production, flagged through `data-railgun-environment` data attributes.
* Finds and replaces references to common libraries like jQuery with the equivalent from a public CDN like cdnjs.com or the Google Libraries CDN.
* Caches and serves the latest versions popular JavaScript libraries on your development machine.

Railgun doesn't require any configuration and works with any project structure. Railgun can work standalone, but you can also use it from [Draughtsman](https://github.com/stdbrouw/draughtsman). Draughtsman integrates with Railgun to give you a full-blown local web server and static site builder, built from the ground up to simplify front-end engineers' workflows.

It is also the engine behind a couple of other projects: 

* [Hector](https://github.com/stdbrouw/hector), a Jekyll-like static site generation framework -- ideal if you're not just optimizing an app but want to use Railgun to build a promotional site or to run your blog.
* [Backbone-express](https://github.com/stdbrouw/backbone-express), a server for your Backbone applications that provides a node.js compatibility layer so Backbone routes and view renders work server-side too.

Railgun uses [Tilt.js](https://github.com/stdbrouw/tilt.js) for template and preprocessor compilation and [Envv](https://github.com/stdbrouw/envv) to provide environments as well as replace common libraries with their equivalent on a public content delivery network.

## API

You can integrate Railgun into your own apps.

1. Give Railgun a library name or path, and it'll return CDN urls it knows of that have that library (doing HEAD requests so it's always up to date, though with a nocheck parameter so you can use it if offline or if you *know* your libraries are available at cdnjs.com.)

<code example>

2. Give Railgun a URL, file of string of HTML, and it'll return a cleaned-up version with all JavaScript and CSS assets nicely packaged together and optimized, references to local libraries replaced with public CDN versions, and cache busters so you can set your expire headers really far in the future. (You'll get back a hash with filenames and their contents.)

<code example>

## Command-line

Point the Railgun command line interface to an HTML file or directory and it will output a nicely optimized version in a directory of your choice.

	# build your app (always does a clean build and empties the build dir first)
	railgun build
		-o --output	    # output dir
		-s --sources	    # add additional CDN sources (in order of preference)

	# draughtsman will respect `data-railgun-environment` and, being a dev server,
	# strip out scripts that target the production environment; but railgun
	# also has its own server, which (as opposed to draughtsman) is as plain to
	# a regular file server as possible, and serves mainly to test out if there are
	# no errors in the packaging process or in your code that targets the production
	# environment only
	#
	# We want to encourage people to use draughtsman, but railgun should be able to stand
	# on its own.
	railgun serve
	    -e --environment    # production by default
	    -f --follow         # serves an endpoint that a GitHub post-commit hook
	                        # can POST to, which prompts Railgun to fetch the latest
	                        # commit from said repository and rebuild the app/site
	                        # [also works on railgun build, which turns that command
	                        # into a long-lived process]

## Issues

If for whatever weird reason the Railgun cache is corrupted, just run `railgun clean` and you'll have a fresh, empty cache.
