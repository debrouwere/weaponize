# Weaponize

Weaponize guides your client-side app from development to production. Bundles and optimizes your assets. Separates dev and production environment. Simplifies working with public and private CDNs.

## Project status

Weaponize is **no longer actively maintained**. It was an experiment to try and create a client-side app builder/optimizer with sensible-enough defaults that you wouldn't need [Grunt](http://gruntjs.com/) or [Gulp](http://gulpjs.com/). But everyone does things slightly differently and people are – rightfully – quite picky about what their build process looks like, so that kind of sort of turned out to be a fool's errand. Oh well!

## SOME NOTES

You know the one drawback to static site generators? It's no fun waiting around
for every file to be regenerated (even if you pass Weaponize only a partial set
based on what you know to be out of date). To fight that, Weaponize is 
ruthlessly parallelized and it doesn't keep a file in memory for any longer 
than it's needed.

Because of this "every file is an island" architecture (we'll have the first
file generated and in your build directory before we've even walked your full 
project tree), there are certain concessions to be made to make up for our 
application's lack of omniscience.

	1. Any CSS or JavaScript you want concatenated into a single 
	   'application.min.js' and 'application.min.css' should be 
	   specified in an entrypoint file, which will be processed
	   before all other files.
	   Other JavaScript or CSS won't disappear, it will simply be added to
	   that base.
	2. Similarly, if you have some templates that you want preprocessed
	   rather than fully processed (e.g. turn those Handlebars into 
	   JavaScript rendering functions that will be available when 
	   loading the page in a browser... rather than trying to actually
	   render the template on the server) these should be in your entrypoint
	   too.
	3. We can inline all CSS and JavaScript. This can be a good idea for 
	   single-page apps, but if you want to use this option for anything
	   other than that you might be losing your sanity (and Weaponize
	   will gobble up memory like nobody's business)

Typically, your entrypoint file is simply your `index.html` (or `index.jade` 
or `index.handlebars` or what not) but the way Weaponizer sees it, it's 
simply a bunch of instructions for how to handle certain files, so if your
project is a little bit more involved you can just as easily create an HTML
file with no body and just a bunch of link and script tags between the head.
It needn't be part of the generated output either, it is simply the file from
which we will determine how to optimize certain things.

You can specify multiple entrypoint files. They will all be loaded and examined
before anything is optimized.

[NOTE: this explanation will make more sense to people when I've first had 
a chance to explain how Weaponize can interpret certain tags and attributes
using `envv` and how it can preprocess any template using `tilt.js`. If you're
using plain HTML and CSS you only really need an entrypoint file so Weaponize
can figure out which JavaScript and CSS it can concatenate. And in those 
cases, it's easy to just note that you should pass the command-line tool
the index of your generated-but-not-optimized project instead of
just the directory (or when passed a directory, complain if it doesn't
find an index.html)]

## Features

* Packages up a client-side app for easy distribution through a CDN or faster serving on your own hardware: minification, concatenation, all that good stuff.
* Preprocesses template languages into HTML, CoffeeScript into JavaScript and stylesheet languages into CSS.
* Filters out code you only need during development and includes code you only need in production, flagged through `data-weaponize-environment` data attributes.
* Finds and replaces references to common libraries like jQuery with the equivalent from a public CDN like cdnjs.com or the Google Libraries CDN.
* Caches and serves the latest versions popular JavaScript libraries on your development machine.

Weaponize doesn't require any configuration and works with any project structure. Weaponize can work standalone, but you can also use it from [Draughtsman](https://github.com/stdbrouw/draughtsman). Draughtsman integrates with Weaponize to give you a full-blown local web server and static site builder, built from the ground up to simplify front-end engineers' workflows.

It is also the rendering engine that powers [Hector](https://github.com/stdbrouw/hector), a nascent Jekyll-like static site generation framework -- ideal if you're not just optimizing an app but want to use Weaponize to build a promotional site or to run your blog.

Weaponize uses [Tilt.js](https://github.com/stdbrouw/tilt.js) for template and preprocessor compilation and [Envv](https://github.com/stdbrouw/envv) to provide environments and replace common libraries with their equivalent on a public content delivery network.

## API

You can integrate Weaponize into your own apps.

1. Give Weaponize a library name or path, and it'll return CDN urls it knows of that have that library (doing HEAD requests so it's always up to date, though with a nocheck parameter so you can use it if offline or if you *know* your libraries are available at cdnjs.com.)

<code example>

2. Give Weaponize a URL, file of string of HTML, and it'll return a cleaned-up version with all JavaScript and CSS assets nicely packaged together and optimized, references to local libraries replaced with public CDN versions, and cache busters so you can set your expire headers really far in the future. (You'll get back a hash with filenames and their contents.)

<code example>

## Command-line

Point the Weaponize command line interface to an HTML file or directory and it will output a nicely optimized version in a directory of your choice.

	# build your app (always does a clean build and empties the build dir first)
	weaponize build
		-o --output	    # output dir
		-s --sources	    # add additional CDN sources (in order of preference)

	# draughtsman will respect `data-weaponize-environment` and, being a dev server,
	# strip out scripts that target the production environment; but weaponize
	# also has its own server, which (as opposed to draughtsman) is as plain to
	# a regular file server as possible, and serves mainly to test out if there are
	# no errors in the packaging process or in your code that targets the production
	# environment only
	#
	# We want to encourage people to use draughtsman, but weaponize should be able to stand
	# on its own.
	weaponize serve
	    -e --environment    # production by default
	    -f --follow         # serves an endpoint that a GitHub post-commit hook
	                        # can POST to, which prompts Weaponize to fetch the latest
	                        # commit from said repository and rebuild the app/site
	                        # [also works on weaponize build, which turns that command
	                        # into a long-lived process]

## Issues

If for whatever weird reason the Weaponize cache is corrupted, just run `weaponize clean` and you'll have a fresh, empty cache.
