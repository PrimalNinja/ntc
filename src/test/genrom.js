// builds the keyword library ROM and keeps its registry - scratch tool, not delivered
//   node genrom.js [platform]       (default cpcfw; needs sjasmplus on the PATH)
// 1. ntcRomAsm makes the ROM's source from the library, using asm/ntc_rom_<platform>.txt
// 2. sjasmplus assembles it (--sym)
// 3. new entries are appended to the registry (numbers for code, addresses / values for
//    variables and constants); entries the library no longer has are marked gone, never removed
// 4. the source is made again with the new registry, assembled, and written to
//    build/rom/NTC<platform>.ASM and .ROM; then run gen.js to bundle the registry
var fs = require('fs');
var path = require('path');
var cp = require('child_process');
var strDir = path.join(__dirname, '..') + '/';
global.window = global;
eval(fs.readFileSync(strDir + 'js/ntc_lib.js', 'utf8').replace(/^var /gm, 'global.'));
eval(fs.readFileSync(strDir + 'js/ntc_parser.js', 'utf8').replace(/^var /gm, 'global.').replace('function IFtoPF', 'global.IFtoPF = function IFtoPF').replace('function ntcParse', 'global.ntcParse = function ntcParse'));
eval(fs.readFileSync(strDir + 'js/ntc_compiler.js', 'utf8').replace(/^var (NTC_ROM\w*)/gm, 'global.$1').replace('function ntcCompile', 'global.ntcCompile = function ntcCompile').replace('function ntcRomAsm', 'global.ntcRomAsm = function ntcRomAsm').replace('function ntcRomRegistry', 'global.ntcRomRegistry = function ntcRomRegistry').replace('function ntcRomHook', 'global.ntcRomHook = function ntcRomHook').replace('function ntcRomFile', 'global.ntcRomFile = function ntcRomFile'));

var strPlat = process.argv[2] || 'cpcfw';
var strRegFile = strDir + 'asm/ntc_rom_' + strPlat + '.txt';
var strOutDir = strDir + 'build/rom/';
var strTmp = fs.mkdtempSync(path.join(require('os').tmpdir(), 'ntcrom'));
var strName = ntcRomFile(strPlat);
var strReg = fs.existsSync(strRegFile) ? fs.readFileSync(strRegFile, 'utf8') : '';

function hex4(int_a) { return '#' + ('000' + (int_a & 0xFFFF).toString(16).toUpperCase()).substr(-4); }

function assemble(strAsm_a)
{
	var objSyms = {};
	fs.writeFileSync(strTmp + '/' + strName + '.ASM', strAsm_a);
	try
	{
		cp.execSync('sjasmplus --nologo --msg=war --sym=rom.sym ' + strName + '.ASM', { cwd: strTmp, stdio: ['ignore', 'pipe', 'pipe'] });
	}
	catch (e)
	{
		console.error(String(e.stdout) + String(e.stderr));
		process.exit(1);
	}
	fs.readFileSync(strTmp + '/rom.sym', 'utf8').split(/\r?\n/).forEach(function(strLine)
	{
		var arrM = strLine.match(/^(\w+):\s*EQU\s+0x([0-9A-Fa-f]+)/);
		if (arrM) { objSyms[arrM[1]] = parseInt(arrM[2], 16); }
	});
	return objSyms;
}

var objRes = ntcRomAsm(strPlat, strReg);
if (objRes.errors.length > 0) { console.error(objRes.errors.join('\n')); process.exit(1); }
var objSyms = assemble(objRes.asm);

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
		if (objSyms[objS.name] === undefined) { console.error('no address for ' + objS.name); process.exit(1); }
		arrLines.push('-\t' + objS.kind + '\t' + objS.name + '\t' + hex4(objSyms[objS.name]));
		intAdded++;
	}
});
strReg = arrLines.join('\n') + '\n';
fs.writeFileSync(strRegFile, strReg);

// again, with the registry as it is now (the asserts check that nothing known moved)
objRes = ntcRomAsm(strPlat, strReg);
objSyms = assemble(objRes.asm);
if (!fs.existsSync(strOutDir)) { fs.mkdirSync(strOutDir, { recursive: true }); }
fs.writeFileSync(strOutDir + strName + '.ASM', objRes.asm);
fs.copyFileSync(strTmp + '/' + strName + '.ROM', strOutDir + strName + '.ROM');
var intSize = fs.statSync(strOutDir + strName + '.ROM').size;
console.log(strName + '.ROM: ' + intSize + ' bytes, code ends ' + hex4(objSyms.ntc_rom_img) + ' (' + (0x10000 - objSyms.ntc_rom_imgend) + ' free), RAM ' +
	hex4(0x8800) + '-' + hex4(objSyms.ntc_rom_imgend_r - 1) + ' and ' + hex4(0x9400) + '-' + hex4(objSyms.ntc_rom_bssend - 1) +
	'; registry: ' + objRes.symbols.length + ' numbers, ' + objRes.vars.length + ' names, ' + intAdded + ' added, ' + intGone + ' gone');
fs.rmSync(strTmp, { recursive: true, force: true });
