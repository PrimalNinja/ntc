// romwhy.js - which library sections the keyword ROM (Library: ROM) leaves out, and why: a
// section that uses a label nothing in the ROM defines is dropped, then whatever uses that
// section, and so on. When genrom.js stops on "... moved: variables and constants keep their
// place", a dropped section is usually why (everything after it moved down).
//
//   node tools/ntccheck/romwhy.js [cpc|cpcmin|cpcfw] [NTC_SRC]   (default cpcfw, ../../src)
//
// Prints each dropped section with the labels it needed that were not there. Sections a CPC
// platform doesn't have (the file system on cpc ...) are expected to be on the list.
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'use strict';
var fs = require('fs'), path = require('path'), vm = require('vm');

var strPlat = process.argv[2] || 'cpcfw';
var strSrc = path.resolve(process.argv[3] || path.join(__dirname, '..', '..', 'src'));
var objCtx = { console: console };
var strComp = fs.readFileSync(path.join(strSrc, 'js', 'ntc_compiler.js'), 'utf8');
var strHook = '\t\t\t\tobjSec_a.keep = false;\n\t\t\t\tblnChanged = true;';

objCtx.window = objCtx;
vm.createContext(objCtx);
['ntc_lib.js', 'ntc_parser.js'].forEach(function(f) { vm.runInContext(fs.readFileSync(path.join(strSrc, 'js', f), 'utf8'), objCtx); });
if (strComp.indexOf(strHook) < 0)
{
	console.log('romwhy: ntcRomAsm has changed - the line that drops a section was not found');
	process.exit(2);
}
objCtx.__dropped = [];
strComp = strComp.replace(strHook, '\t\t\t\t__dropped.push({ name: objSec_a.name, missing: usesOf(objSec_a).filter(function(s) { return objDefined[s] === undefined; }) });\n' + strHook);
vm.runInContext(strComp, objCtx);
var r = objCtx.ntcRomAsm(strPlat, fs.readFileSync(path.join(strSrc, 'asm', 'ntc_rom_' + strPlat + '.txt'), 'utf8'), { measure: true });
(r.errors || []).forEach(function(e) { console.log('error: ' + e.msg); });
if (objCtx.__dropped.length === 0)
{
	console.log(strPlat + ': every section is in the ROM');
}
objCtx.__dropped.forEach(function(d)
{
	var arrU = d.missing.filter(function(s, i, a) { return a.indexOf(s) === i; });

	console.log(strPlat + ': ' + d.name + ' left out - needs ' + arrU.join(' '));
});
