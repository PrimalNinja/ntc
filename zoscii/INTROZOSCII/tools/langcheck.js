// langcheck.js - checks a translation (tools/lang/xx.js) of tools/text.js: the same keys in the same order, every character in the font,
// no more lines than the English and no line wider than the screen allows.      node tools/langcheck.js es [-v]
// A line may be 52 characters (6 pixels each from x = 8); a short English entry (30 or fewer characters wide) is a label in a box: it may be 2 wider.
// (c) 2026 Cyborg Unicorn Pty Ltd
// ES5.
'use strict';
var LG = require('./lang.js');
var en = require('./text.js');
var code = process.argv[2];
var verbose = process.argv[3] === '-v';
var tr = require('./lang/' + code + '.js');
var bad = 0, i;
function lines(s) { return s.split('\n'); }
function width(s) { var w = 0; lines(s).forEach(function(l) { if (l.length > w) { w = l.length; } }); return w; }
if (tr.length !== en.length) { console.log('entries: ' + tr.length + ', the English has ' + en.length); bad++; }
for (i = 0; i < en.length && i < tr.length; i++)
{
	var e = en[i], t = tr[i], why = [];
	if (e[0] !== t[0]) { why.push('key ' + t[0] + ' where the English has ' + e[0]); }
	else
	{
		try { LG.encode(t[1], t[0]); } catch (x) { why.push(x.message); }
		var el = lines(e[1]).length, tl = lines(t[1]).length, ew = width(e[1]), tw = width(t[1]);
		var lim = ew <= 30 ? ew + 2 : 52;
		if (tl > el) { why.push(tl + ' lines, the English has ' + el); }
		if (tw > lim) { why.push('width ' + tw + ' (most ' + lim + '): ' + lines(t[1]).filter(function(l) { return l.length > lim; })[0]); }
		if (/[a-z]/.test(t[1]) && verbose) { /* lower case is shown as capitals: fine */ }
	}
	if (why.length) { bad++; console.log(t[0] + ': ' + why.join('; ')); }
}
console.log(bad ? bad + ' problems' : 'ok: ' + tr.length + ' entries');
process.exit(bad ? 1 : 0);
