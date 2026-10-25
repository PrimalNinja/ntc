// compare.js - two NTC trees' compilers on the same programs: every program in A's src/bas
// (a .bas, or a folder with Main.bas - its .bas and .cls), for each platform named, compiled
// by A's compiler and by B's (each from its own src/js); the output (the asm, errors and
// warnings) compared. For checking a merge or a change that should not change what is built.
//
//   node tools/ntccheck/compare.js TREE_A TREE_B [platform ...]   (none: every platform A has)
//   --list    print each program / platform pair as it goes
//
// TREE_A / TREE_B: NTC folders (the ones with src/ in them). Exit code 1 when any differ.
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'use strict';
var fs = require('fs'), path = require('path'), vm = require('vm');

function loadCompiler(strTree_a)
{
	var strJs = path.join(strTree_a, 'src', 'js');
	var objCtx = { console: console };

	objCtx.window = objCtx;
	vm.createContext(objCtx);
	['ntc_lib.js', 'ntc_parser.js', 'ntc_compiler.js', 'ntc_flavour_js.js', 'ntc_flavour_php.js', 'ntc_flavour_loco.js'].forEach(function(strF_a)
	{
		var strP = path.join(strJs, strF_a);

		if (fs.existsSync(strP))
		{
			vm.runInContext(fs.readFileSync(strP, 'utf8'), objCtx, { filename: strP });
		}
	});
	return objCtx;
}

function programs(strTree_a)
{
	var strBas = path.join(strTree_a, 'src', 'bas');
	var arrOut = [];

	fs.readdirSync(strBas).sort().forEach(function(strN_a)
	{
		var strP = path.join(strBas, strN_a);

		if (/\.bas$/i.test(strN_a) && fs.statSync(strP).isFile())
		{
			arrOut.push({ name: strN_a, files: [strN_a] });
		}
		else if (fs.statSync(strP).isDirectory() && fs.existsSync(path.join(strP, 'Main.bas')))
		{
			arrOut.push({ name: strN_a + '/', files: fs.readdirSync(strP).filter(function(f) { return /\.(bas|cls)$/i.test(f); }).sort(function(a, b) { return (a === 'Main.bas') ? -1 : (b === 'Main.bas') ? 1 : a.localeCompare(b); }).map(function(f) { return strN_a + '/' + f; }) });
		}
	});
	return arrOut;
}

function compile(objCtx_a, strTree_a, objProg_a, strPlat_a)
{
	var arrFiles = objProg_a.files.map(function(f) { return { name: path.basename(f), text: fs.readFileSync(path.join(strTree_a, 'src', 'bas', f), 'utf8') }; });

	try
	{
		var r = objCtx_a.ntcCompile((arrFiles.length === 1) ? arrFiles[0].text : arrFiles, { platform: strPlat_a });

		return JSON.stringify([r.asm, (r.errors || []).map(function(e) { return e.line + ':' + e.msg; }), (r.warnings || []).map(function(e) { return e.line + ':' + e.msg; })]);
	}
	catch (e)
	{
		return 'THROW ' + e.message;
	}
}

var arrArgs = process.argv.slice(2);
var blnList = arrArgs.indexOf('--list') >= 0;
arrArgs = arrArgs.filter(function(a) { return a !== '--list'; });
if (arrArgs.length < 2)
{
	console.log('node compare.js TREE_A TREE_B [platform ...] [--list]');
	process.exit(2);
}
var strA = path.resolve(arrArgs[0]), strB = path.resolve(arrArgs[1]);
var objA = loadCompiler(strA), objB = loadCompiler(strB);
var arrPlat = arrArgs.slice(2);
if (arrPlat.length === 0)
{
	arrPlat = Object.keys(objA.NTC_PLATFORMS || {});
}
var intSame = 0, intDiff = 0, intSkip = 0;
arrPlat.forEach(function(strPlat_a)
{
	if (!(objB.NTC_PLATFORMS || {})[strPlat_a])
	{
		console.log('skip ' + strPlat_a + ' (not in B)');
		return;
	}
	programs(strA).forEach(function(objP_a)
	{
		if (!objP_a.files.every(function(f) { return fs.existsSync(path.join(strB, 'src', 'bas', f)); }))
		{
			intSkip++;
			return;
		}
		var blnSame = compile(objA, strA, objP_a, strPlat_a) === compile(objB, strB, objP_a, strPlat_a);

		if (blnSame) { intSame++; } else { intDiff++; console.log('DIFF ' + strPlat_a + ' ' + objP_a.name); }
		if (blnList && blnSame) { console.log('same ' + strPlat_a + ' ' + objP_a.name); }
	});
});
console.log('same ' + intSame + ', different ' + intDiff + (intSkip ? ', not in B ' + intSkip : ''));
process.exit(intDiff ? 1 : 0);
