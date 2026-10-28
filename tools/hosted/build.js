// build.js - NTC's page as a folder for a web server: hosted/ at NTC's top, from src/ - ntc.html
// and the files it loads (the scripts and stylesheets it names), an index.html that opens it, and
// htaccess (Apache's ".htaccess", without the dot: rename it on the server) that stops directory
// listings. Upload the folder's contents as they are; nothing runs on the server - the page
// compiles in the visitor's browser, and their files stay on their own PC.
//
//   node tools/hosted/build.js            (from NTC's top folder, or anywhere)
//
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'use strict';
var fs = require('fs'), path = require('path');

var TOP = path.join(__dirname, '..', '..');
var SRC = path.join(TOP, 'src');
var OUT = path.join(TOP, 'hosted');

var strPage = fs.readFileSync(path.join(SRC, 'ntc.html'), 'utf8');
// the files the page loads: every local src="..." / href="..." (not http(s):, not # or mailto:)
var arrFiles = [];
strPage.replace(/(?:src|href)="([^"#:]+)"/g, function(m, f) { if (arrFiles.indexOf(f) < 0) { arrFiles.push(f); } return m; });

fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(OUT, { recursive: true });
fs.writeFileSync(path.join(OUT, 'ntc.html'), strPage);
arrFiles.forEach(function(f)
{
	var strFrom = path.join(SRC, f), strTo = path.join(OUT, f);

	if (!fs.existsSync(strFrom)) { throw new Error('ntc.html loads ' + f + ', not in src/'); }
	fs.mkdirSync(path.dirname(strTo), { recursive: true });
	fs.copyFileSync(strFrom, strTo);
});
// index.html: the folder's address opens the page
fs.writeFileSync(path.join(OUT, 'index.html'), [
	'<!DOCTYPE html>',
	'<html lang="en">',
	'<head>',
	'<meta charset="utf-8">',
	'<title>NTC BASIC</title>',
	'<meta http-equiv="refresh" content="0; url=ntc.html">',
	'</head>',
	'<body><a href="ntc.html">NTC BASIC</a></body>',
	'</html>', ''].join('\n'));
// htaccess: no directory listings (Apache; rename to .htaccess on the server)
fs.writeFileSync(path.join(OUT, 'htaccess'), [
	'# Rename this file to .htaccess on an Apache server.',
	'# No directory listings: a folder without an index page shows "Forbidden", not its files.',
	'Options -Indexes',
	'# The folder\'s own address opens the page.',
	'DirectoryIndex index.html ntc.html', ''].join('\n'));
fs.writeFileSync(path.join(OUT, 'README.txt'), [
	'NTC BASIC - the hosted page',
	'',
	'Upload everything in this folder to a folder on a web server (any static host).',
	'On Apache, rename htaccess to .htaccess: it stops directory listings.',
	'Then open the folder\'s address (index.html opens ntc.html).',
	'',
	'Nothing runs on the server. The page is HTML, JavaScript and CSS: it compiles in the',
	'visitor\'s browser, opens and saves files on their own PC (and keeps the project they',
	'are working on in their browser\'s local storage). Assembling the .asm is done on their',
	'PC with sjasmplus, as with the page run from NTC\'s src/ folder.',
	'',
	'Made by NTC\'s tools/hosted/build.js from src/ - run it again after changing the page.',
	'',
	'(c) 2026 Cyborg Unicorn Pty Ltd - https://cyborgunicorn.com.au', ''].join('\n'));
console.log('hosted/: ntc.html, index.html, htaccess, README.txt and ' + arrFiles.length + ' files it loads (' + arrFiles.join(', ') + ')');
