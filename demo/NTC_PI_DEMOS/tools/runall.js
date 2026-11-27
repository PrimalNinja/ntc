// runall.js - every NTC PI DEMO run on the emulated CPC against a real cosd (tools/pirun.py),
// once as a CPC-CPLink and once as a CPLink2; what each printed goes to docs/results/, a line
// each here.
//
//   node tools/runall.js [--only=PI01LINK,...] [--card=cplink|cplink2]
//
//   NTC, COS_PI           as pirun.py's
//   PI_MODELS, NTCK_NODE  for PI12MIND: a folder with GEN.MDL, and the built pi/ntck/ntck.node
// Needs python3 with the z80 module, node, sjasmplus on the PATH (as NTC's own tests).
// (c) 2026 Cyborg Unicorn Pty Ltd
'use strict';
var fs = require('fs'), path = require('path'), cp = require('child_process');
var ROOT = path.resolve(__dirname, '..'), OUT = path.join(ROOT, 'docs', 'results');
var arrProg = fs.readdirSync(path.join(ROOT, 'src')).filter(function(f) { return /^PI\d\d\w*\.bas$/.test(f); }).sort().map(function(f) { return f.slice(0, -4); });
var objArg = {};
process.argv.slice(2).forEach(function(a) { var m = a.match(/^--(\w+)=(.*)$/); if (m) { objArg[m[1]] = m[2]; } });
var arrCards = objArg.card ? [objArg.card] : ['cplink', 'cplink2'], intBad = 0;

fs.mkdirSync(OUT, { recursive: true });
if (objArg.only) { arrProg = arrProg.filter(function(p) { return objArg.only.toUpperCase().split(',').indexOf(p) >= 0; }); }
arrCards.forEach(function(strCard)
{
	arrProg.forEach(function(p)
	{
		var arrSrc = [path.join(ROOT, 'src', p + '.bas'), path.join(ROOT, 'src', 'Link.cls')];
		if (/^PI1[45]/.test(p)) { arrSrc.push(path.join(ROOT, 'src', 'Pi.cls'), path.join(ROOT, 'src', 'Art.cls')); }
		var r = cp.spawnSync('python3', [path.join(__dirname, 'pirun.py'), '--card=' + strCard, '--limit=200000', '--keys=x'].concat(arrSrc), { encoding: 'utf8', timeout: 600000 });
		var strText = (r.stdout || '') + (r.stderr || ''), m = strText.match(/(\d+) ok, (\d+) failed( - ALL PASS)?/);
		var blnOk = !!(m && m[3]) && /--- ended/.test(strText) && !/--- FAIL/.test(strText);
		fs.writeFileSync(path.join(OUT, p + '-' + strCard + '.txt'), strText);
		if (!blnOk) { intBad++; }
		console.log((blnOk ? 'ok   ' : 'FAIL ') + (p + '        ').slice(0, 9) + (strCard + '   ').slice(0, 8) + (m ? m[0] : 'no result line'));
	});
});
console.log(intBad ? intBad + ' did not pass' : 'ALL PASS');
process.exit(intBad ? 1 : 0);
