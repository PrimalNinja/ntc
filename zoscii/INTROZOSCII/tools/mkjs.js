// mkjs.js - makes data-zoscii.js for the PotentJS version of INTRODUCTION TO ZOSCII from assets/ and tools/text.js
// (c) 2026 Cyborg Unicorn Pty Ltd
//
//   node tools/mkjs.js <the game's folder>        (writes <folder>/js/data-zoscii.js)
//
// ES5.
'use strict';
var fs = require('fs');
var path = require('path');
var ROOT = path.join(__dirname, '..');
var A = path.join(ROOT, 'assets');
var out = process.argv[2];
if (!out || !require('fs').existsSync(require('path').join(out, 'game.htm'))) { console.error('mkjs: give the JS game folder (the one with game.htm)'); process.exit(1); }
if (!out) { console.log('usage: node tools/mkjs.js <game folder>'); process.exit(1); }

function b64(n) { return fs.readFileSync(path.join(A, n)).toString('base64'); }
var man = JSON.parse(fs.readFileSync(path.join(A, 'manifest.json'), 'utf8'));
var LG = require('./lang.js');
// the text of an edition: the same as the Next's, except where the Next itself is named. Text is stored as font codes (128 and up the extra glyphs)
function makeTX(lang)
{
	var txt = require(lang === 'en' ? './text.js' : './lang/' + lang + '.js');
	var TX = {};
	txt.forEach(function(t) { if (t) { TX[t[0]] = t[1]; } });
	var web = {};
	if (lang === 'en')
	{
		web = {
			TX_D_INTRO: ["A ROM IS MADE NOW FROM THE NEXT'S OWN MEMORY AND\nTHE TIMING OF YOUR KEYS: 128 KB, OR 256 NIBBLES FOR\nTHE MICRO PROTOCOLS. IT HAS NEVER EXISTED BEFORE.", "A ROM IS MADE NOW FROM THE BROWSER'S RANDOM SOURCE\nAND THE TIMING OF YOUR KEYS: 128 KB, OR 256 NIBBLES\nFOR THE MICRO PROTOCOLS. IT NEVER EXISTED BEFORE."],
			TX_D_GUESS: ["A ROM IS MADE NOW FROM THE NEXT'S OWN MEMORY AND\nTHE TIMING OF YOUR KEYS: 128 KB, OR 256 NIBBLES FOR\nTHE MICRO PROTOCOLS.", "A ROM IS MADE NOW FROM THE BROWSER'S RANDOM SOURCE\nAND THE TIMING OF YOUR KEYS: 128 KB, OR 256 NIBBLES\nFOR THE MICRO PROTOCOLS."]
		};
	}
	else { web = require('./lang/' + lang + '.js').web || {}; }
	// the browser version: where the Next is named
	Object.keys(web).forEach(function(k)
	{
		var r = TX[k].replace(web[k][0], web[k][1]);
		if (r === TX[k]) { throw new Error(lang + ': override did not apply: ' + k); }
		TX[k] = r;
	});
	Object.keys(TX).forEach(function(k)
	{
		TX[k].split('\n').forEach(function(l) { if (l.length > 52) { throw new Error(lang + ' ' + k + ': line of ' + l.length + ': ' + l); } });
		if (lang === 'en' && /NEXT'S/.test(TX[k])) { throw new Error(k + ' still names the Next'); }
		TX[k] = String.fromCharCode.apply(null, LG.encode(TX[k], k));       // font codes
	});
	return TX;
}
// the 5 x 7 font, as the Next's tools/assets.js has it
var src = fs.readFileSync(path.join(__dirname, 'assets.js'), 'utf8');
var fm = /var FONT = '([^']+)'/.exec(src);
var FONT = [];
fm[1].split(',').forEach(function(g) { g.trim().split(' ').forEach(function(h) { FONT.push(parseInt(h, 16)); }); });
if (FONT.length !== 59 * 5) { throw new Error('font is ' + FONT.length + ' bytes'); }
FONT = FONT.concat(LG.extFont());

// the word list, the same filter as assets.js
var words = fs.readFileSync(path.join(A, 'words.txt'), 'utf8').split(/\r?\n/).filter(function(x) { return /^[a-z]{1,8}$/.test(x); });
var BLOCK = ('muslim muslims islam islamic jew jews jewish christ christian christians catholic catholics hindu hindus buddhist sikh allah god jihad church mosque ' +
  'arab arabs israel israeli palestine palestinian iraq iran afghan taliban isis hamas terror terrorism terrorist nazi nazis hitler ' +
  'war wars bomb bombs kill killed killing rape slave slavery gay racist racism negro').split(' ');
words = words.filter(function(x) { return BLOCK.indexOf(x) < 0; });
if (words.length > 8192) { words = words.slice(0, 8192); }

var o = [];
o.push('// data-zoscii.js - INTRODUCTION TO ZOSCII: the text, the font, the ROMs, the example files and the splash pictures (made by tools/mkjs.js: do not edit)');
o.push('// (c) 2026 Cyborg Unicorn Pty Ltd');
o.push('var ZD = {');
o.push('FONT: ' + JSON.stringify(FONT) + ',');
o.push('ROMS: ["' + b64('rom1.bin') + '",');
o.push('"' + b64('rom2.bin') + '",');
o.push('"' + b64('rom3.bin') + '"],');
o.push('SMALL: "' + b64('rom_s.bin') + '",');
o.push('FILES: [' + man.files.map(function(f) { return '"' + b64(f.file) + '"'; }).join(',') + '],');
o.push('ALT: "' + b64('alt_b.bin') + '",');
o.push('MAN: ' + JSON.stringify({ files: man.files.map(function(f) { return { name: f.name, layers: f.layers, win: f.win }; }), cribs: man.cribs, altFile: man.altFile }) + ',');
o.push('WORDS: "' + words.join(' ') + '",');
o.push('SPLASH: ["' + b64('cyborgunicorn-logo.scr') + '"]');		// the web version has the one splash: it is not NTC BASIC
o.push('};');
fs.mkdirSync(path.join(out, 'js'), { recursive: true });
fs.writeFileSync(path.join(out, 'js', 'data-zoscii.js'), o.join('\n') + '\n');
// the text of each edition: js/text-en.js, text-es.js, text-ru.js (game.htm?lang=es). Only the editions whose tools/lang file exists.
var nt = 0;
['en', 'es', 'ru'].forEach(function(lang)
{
	if (lang !== 'en' && !fs.existsSync(path.join(__dirname, 'lang', lang + '.js'))) { return; }
	var TX = makeTX(lang);
	fs.writeFileSync(path.join(out, 'js', 'text-' + lang + '.js'), '// text-' + lang + '.js - INTRODUCTION TO ZOSCII, the text of this edition as font codes (made by tools/mkjs.js: do not edit)\n// (c) 2026 Cyborg Unicorn Pty Ltd\nZD.TX = ' + JSON.stringify(TX) + ';\n');
	nt++;
});
console.log('data-zoscii.js: ' + (o.join('\n').length >> 10) + ' KB, ' + words.length + ' words, ' + nt + ' editions');
