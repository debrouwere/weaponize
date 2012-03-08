Cdnify optimizes your apps and simplifies working with public and private CDNs.

## Overview

Cdnify provides five basic features.

* Packages up a client-side app for easy distribution through a CDN (or faster serving on your own hardware): minification, concatenation, all that good stuff.
* Preprocesses template languages into HTML, CoffeeScript into JavaScript and stylesheet languages into CSS.
* Filters out code you only need during development, flagged by you using a `data-cdnify-environment` data attribute.
* Finds and replaces references to common libraries like jQuery with the equivalent from a public CDN like cdnjs.com or the Google Libraries CDN.
* Caches and serves the latest versions popular JavaScript libraries on your development machine.

Cdnify doesn't require any configuration and works with any project structure. Cdnify can work standalone, but you can also use it from Draughtsman. Draughtsman integrates with Cdnify to give you a full-blown local web server and static site builder, built from the ground up to simplify front-end engineers' workflows.

## Airplane mode

Cdnify can act as a local file server (either standalone or hooked to another server in node.js) that will make popular JavaScript libraries available locally. The first time you ask for a file (say, `/1.7.2/jquery.min.js`) Cdnify will fetch it from a public CDN, either the Google Libraries CDN or CloudFlare's cdnjs.com. But any requests from that moment on will be served from a cached version on your own computer. Speeds things up and makes sure you can do client-side development without an internet connection.

(You can also cache any random file locally, using /?url=<bla> and optionally &ttl to specify when to invalidate the cache for unversioned files.)

## API

You can integrate Cdnify into your own apps.

1. Give Cdnify a library name or path, and it'll return CDN urls it knows of that have that library.

<code example>

2. Give Cdnify a URL, file of string of HTML, and it'll return a cleaned-up version with all JavaScript and CSS assets nicely packaged together and optimized, references to local libraries replaced with public CDN versions, and cache busters so you can set your expire headers really far in the future. (You'll get back a hash with filenames and their contents.)

<code example>

## Command-line

Point the Cdnify command line interface to an HTML file or directory and it will output a nicely optimized version in a directory of your choice.

	# build your app (always does a clean build and empties the build dir first)
	cdnify build
		-o --output	# output dir
		-s --sources	# add additional CDN sources (in order of preference)
	# serve the local file cache
	cdnify serve
		-p --port
	# clear the local file cache
	cdnify clean
	# serve your app: use draughtsman instead!
	draughtsman

## Issues

If for whatever weird reason the Cdnify cache is corrupted, just run `cdnify clean` and you'll have a fresh, empty cache.