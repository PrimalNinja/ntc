// builds the keyword library ROM set and keeps its registry - scratch tool, not delivered
//   node genrom.js [platform] [--cap=bytes] [--out=dir] [--place=section:rom,...]
//   (default cpcfw; needs sjasmplus on the PATH)
// 1. ntcRomAsm makes the ROM's source from the library, using asm/ntc_rom_<platform>.txt
// 2. sjasmplus assembles it (--sym)
// 3. new entries are appended to the registry (numbers for code, addresses / values for
//    variables and constants); entries the library no longer has are marked gone, never removed
// 4. the set: when everything doesn't fit in one ROM (or --cap bytes), @far sections move to
//    ROM 2, 3 ... (NTC<platform>2.ROM ...) until each fits; the source is made again and
//    assembled, and written to build/rom/ (or --out): NTC<platform>.ASM and the ROMs. Then run
//    gen.js to bundle the registry. --out (tests: a forced split with --cap) leaves the
//    registry file alone. --place puts sections in ROMs by hand.
var fs = require('fs');
var path = require('path');
var cp = require('child_process');
var strDir = path.join(__dirname, '..', 'src') + '/';
global.window = global;
eval(fs.readFileSync(strDir + 'js/ntc_lib.js', 'utf8').replace(/^var /gm, 'global.'));
eval(fs.readFileSync(strDir + 'js/ntc_parser.js', 'utf8').replace(/^var /gm, 'global.').replace('function IFtoPF', 'global.IFtoPF = function IFtoPF').replace('function ntcParse', 'global.ntcParse = function ntcParse'));
eval(fs.readFileSync(strDir + 'js/ntc_compiler.js', 'utf8').replace(/^var (NTC_ROM\w*)/gm, 'global.$1').replace('function ntcCompile', 'global.ntcCompile = function ntcCompile').replace('function ntcRomAsm', 'global.ntcRomAsm = function ntcRomAsm').replace('function ntcRomRegistry', 'global.ntcRomRegistry = function ntcRomRegistry').replace('function ntcRomHook', 'global.ntcRomHook = function ntcRomHook').replace('function ntcRomFile', 'global.ntcRomFile = function ntcRomFile'));
eval(fs.readFileSync(strDir + 'js/ntc_flavour_js.js', 'utf8'));
eval(fs.readFileSync(strDir + 'js/ntc_flavour_loco.js', 'utf8'));

var strPlat = 'cpcfw';
var intCap = 16384;
var strOutDir = path.join(__dirname, '..', 'build', 'rom') + '/';
var blnOut = false;
var objHand = null;
process.argv.slice(2).forEach(function(strA)
{
	if (strA.substr(0, 6) === '--cap=') { intCap = parseInt(strA.substr(6), 10); }
	else if (strA.substr(0, 6) === '--out=') { strOutDir = path.resolve(strA.substr(6)) + '/'; blnOut = true; }
	else if (strA.substr(0, 8) === '--place=')
	{
		objHand = {};
		strA.substr(8).split(',').forEach(function(strP) { var arrP = strP.split(':'); objHand[arrP[0]] = parseInt(arrP[1], 10); });
	}
	else { strPlat = strA; }
});
var strRegFile = strDir + 'asm/ntc_rom_' + strPlat + '.txt';
var strTmp = fs.mkdtempSync(path.join(require('os').tmpdir(), 'ntcrom'));
var strName = ntcRomFile(strPlat);
var strReg = fs.existsSync(strRegFile) ? fs.readFileSync(strRegFile, 'utf8') : '';

function hex4(int_a) { return '#' + ('000' + (int_a & 0xFFFF).toString(16).toUpperCase()).substr(-4); }

// sjasmplus: the symbols, or null when it fails (blnQuiet: no message)
function assemble(strAsm_a, blnQuiet_a)
{
	var objSyms = {};
	fs.readdirSync(strTmp).forEach(function(strF) { fs.unlinkSync(strTmp + '/' + strF); });
	fs.writeFileSync(strTmp + '/' + strName + '.ASM', strAsm_a);
	try
	{
		cp.execSync('sjasmplus --nologo --msg=war --sym=rom.sym ' + strName + '.ASM', { cwd: strTmp, stdio: ['ignore', 'pipe', 'pipe'] });
	}
	catch (e)
	{
		if (!blnQuiet_a) { console.error(String(e.stdout) + String(e.stderr)); }
		return null;
	}
	fs.readFileSync(strTmp + '/rom.sym', 'utf8').split(/\r?\n/).forEach(function(strLine)
	{
		var arrM = strLine.match(/^(\w+):\s*EQU\s+0x([0-9A-Fa-f]+)/);
		if (arrM) { objSyms[arrM[1]] = parseInt(arrM[2], 16); }
	});
	return objSyms;
}
function fail(str_a) { console.error(str_a); process.exit(1); }

var objRes = ntcRomAsm(strPlat, strReg, { measure: true });
if (objRes.errors.length > 0) { fail(objRes.errors.map(function(o) { return o.msg || o; }).join('\n')); }
var objSyms = assemble(objRes.asm);
if (objSyms === null) { process.exit(1); }

// the registry: existing lines kept (gone marked), new ones appended
var objReg = ntcRomRegistry(strReg);
var objKind = {};
objRes.symbols.forEach(function(objS) { objKind[objS.name] = objS.kind; });
objRes.vars.forEach(function(objS) { objKind[objS.name] = objS.kind; });
var arrLines = [];
if (strReg.length === 0)
{
	arrLines.push('; NTC keyword library ROM registry - ' + strPlat);
	arrLines.push('; Permanent and append-only: a program built with Library: ROM keeps these numbers,');
	arrLines.push('; names and addresses, so any later ROM must keep them. Written by test/genrom.js.');
	arrLines.push(';   <number> code <name>        a routine: the ROM\'s patcher turns the number into its address');
	arrLines.push(';   - data|bss <name> <addr>     a variable at a fixed RAM address');
	arrLines.push(';   - const <name> <value>       a constant');
	arrLines.push(';   gone: no longer in the ROM (the number stays used)');
}
var intAdded = 0;
var intGone = 0;
String(strReg).split(/\r?\n/).forEach(function(strLine)
{
	var arrM = strLine.match(/^\s*(\d+|-)\s+(code|data|bss|const|gone)\s+([A-Za-z_]\w*)/);
	if (arrM && (arrM[2] !== 'gone') && ((objKind[arrM[3]] === undefined) || (objKind[arrM[3]] === 'gone')))
	{
		strLine = strLine.replace(/\b(code|data|bss|const)\b/, 'gone');
		intGone++;
	}
	if (strLine.length > 0) { arrLines.push(strLine); }
});
objRes.symbols.forEach(function(objS)
{
	if (!objS.known && (objS.kind === 'code'))
	{
		arrLines.push(objS.num + '\tcode\t' + objS.name);
		intAdded++;
	}
});
objRes.vars.forEach(function(objS)
{
	if (!objS.known && (objS.kind !== 'gone'))
	{
		if (objSyms[objS.name] === undefined) { fail('no address for ' + objS.name); }
		arrLines.push('-\t' + objS.kind + '\t' + objS.name + '\t' + hex4(objSyms[objS.name]));
		intAdded++;
	}
});
strReg = arrLines.join('\n') + '\n';
if (!blnOut) { fs.writeFileSync(strRegFile, strReg); }

// the set: the measuring build has everything in one ROM (from #4000), with the @far sections
// marked; they move out, in order, until the main ROM fits, then fill ROM 2, 3 ...
var objM = ntcRomAsm(strPlat, strReg, { measure: true });
var objMs = assemble(objM.asm);
if (objMs === null) { process.exit(1); }
var intMain = objMs.ntc_rom_mend - 0x4000;
var arrFar = objM.chunks.filter(function(objC) { return objC.far; }).map(function(objC)
{
	return { name: objC.name, size: objMs['ntc_rom_me' + objC.idx] - objMs['ntc_rom_ms' + objC.idx], deps: objC.deps };
});
// @far sections that use each other move together (a far call costs about 200 T states): groups
// joined through their dependencies, kept in source order
(function()
{
	var objGroup = {};
	arrFar.forEach(function(objF, intI) { objGroup[objF.name] = intI; });
	var blnMore = true;
	while (blnMore)
	{
		blnMore = false;
		arrFar.forEach(function(objF)
		{
			objF.deps.forEach(function(strD)
			{
				if ((objGroup[strD] !== undefined) && (objGroup[strD] !== objGroup[objF.name]))
				{
					var intA = Math.min(objGroup[strD], objGroup[objF.name]);
					var intB = Math.max(objGroup[strD], objGroup[objF.name]);
					Object.keys(objGroup).forEach(function(str) { if (objGroup[str] === intB) { objGroup[str] = intA; } });
					blnMore = true;
				}
			});
		});
	}
	arrFar.forEach(function(objF) { objF.group = objGroup[objF.name]; });
})();
var objPlace = {};
var intXc = 12;		// a guess at the far call code each moved section adds to the main ROM (its RAM image)
if (objHand !== null)
{
	objPlace = objHand;
}
else if (intMain > intCap)
{
	var intRom = 1;
	var intFill = 40;		// the other ROMs: header and block
	var intNeed = intMain - intCap + 80;
	var arrGroups = [];
	arrFar.forEach(function(objF) { if (arrGroups.indexOf(objF.group) < 0) { arrGroups.push(objF.group); } });
	arrGroups.forEach(function(intG)
	{
		var arrIn = arrFar.filter(function(objF) { return objF.group === intG; });
		var intSize = arrIn.reduce(function(intT, objF) { return intT + objF.size; }, 0);
		if (intNeed <= 0) { return; }
		if ((intFill + intSize > intCap) && (intFill > 40)) { intRom++; intFill = 40; }
		arrIn.forEach(function(objF)
		{
			if (intFill + objF.size > intCap) { intRom++; intFill = 40; }		// (a group bigger than a ROM is split)
			objPlace[objF.name] = intRom;
			intFill += objF.size;
		});
		intNeed -= intSize - intXc * 8 * arrIn.length;
	});
}
// build it, and move one more section while a ROM is too big
var objFin = null;
var objFs = null;
for (var intTry = 0; intTry < 40; intTry++)
{
	objFin = ntcRomAsm(strPlat, strReg, { place: objPlace });
	if (objFin.errors.length > 0) { fail(objFin.errors.map(function(o) { return o.msg || o; }).join('\n')); }
	objFs = assemble(objFin.asm, true);
	var blnFits = (objFs !== null) && ((objFs.ntc_rom_imgend - 0xC000) <= intCap);
	for (var intK = 1; blnFits && (intK < objFin.roms); intK++)
	{
		blnFits = (objFs['ntc_rom' + intK + '_end'] - 0xC000) <= intCap;
	}
	if (blnFits) { break; }
	if (objHand !== null) { assemble(objFin.asm); fail('the set as placed does not fit'); }
	// the next @far section not yet out of the main ROM goes to the last ROM (or a new one)
	var objNext = arrFar.filter(function(objF) { return !objPlace[objF.name]; })[0];
	var intLast = 1;
	Object.keys(objPlace).forEach(function(str) { intLast = Math.max(intLast, objPlace[str]); });
	if ((objFs !== null) && (objFin.roms > 1) && ((objFs['ntc_rom' + (objFin.roms - 1) + '_end'] - 0xC000) > intCap))
	{
		// the last ROM is too big: its last section to a new ROM
		var arrIn = Object.keys(objPlace).filter(function(str) { return objPlace[str] === intLast; });
		objPlace[arrIn[arrIn.length - 1]] = intLast + 1;
		continue;
	}
	if (!objNext) { assemble(objFin.asm); fail('no more @far sections to move: it does not fit'); }
	objPlace[objNext.name] = intLast;
}
if (objFs === null) { assemble(objFin.asm); process.exit(1); }

if (!fs.existsSync(strOutDir)) { fs.mkdirSync(strOutDir, { recursive: true }); }
fs.writeFileSync(strOutDir + strName + '.ASM', objFin.asm);
var arrReport = [];
for (var intR = 0; intR < Math.max(objFin.roms, 9); intR++)
{
	var strF = strName + ((intR > 0) ? String(intR + 1) : '') + '.ROM';
	if (intR < objFin.roms)
	{
		fs.copyFileSync(strTmp + '/' + strF, strOutDir + strF);
		var intEnd = (intR === 0) ? objFs.ntc_rom_imgend : objFs['ntc_rom' + intR + '_end'];
		arrReport.push(strF + ' ' + (intEnd - 0xC000) + ' bytes used (' + (0x10000 - intEnd) + ' free)');
	}
	else if (fs.existsSync(strOutDir + strF))
	{
		fs.unlinkSync(strOutDir + strF);		// a ROM of an earlier, bigger set
	}
}
console.log(strName + ' set: ' + objFin.roms + ' ROM' + ((objFin.roms > 1) ? 's' : '') + ' - ' + arrReport.join(', ') + '; RAM ' +
	hex4(0x8800) + '-' + hex4(objFs.ntc_rom_imgend_r - 1) + ' and ' + hex4(0x9400) + '-' + hex4(objFs.ntc_rom_bssend - 1) +
	'; registry: ' + objFin.symbols.length + ' numbers, ' + objFin.vars.length + ' names, ' + intAdded + ' added, ' + intGone + ' gone' +
	(blnOut ? ' (registry file not written: --out)' : ''));
Object.keys(objPlace).forEach(function(str) { console.log('  ' + str + ' -> ROM ' + objPlace[str]); });
objFin.cross.forEach(function(str) { console.log('  cross: ' + str); });
fs.rmSync(strTmp, { recursive: true, force: true });
