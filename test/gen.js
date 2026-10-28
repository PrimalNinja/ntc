// regenerates js/ntc_lib.js from the .asm files - scratch tool, not delivered
var fs = require('fs');
var strDir = require('path').join(__dirname, '..', 'src') + '/';
function read(f) { return fs.readFileSync(strDir + f, 'utf8'); }
var strLib = read('asm/ntc_lib_gen.asm') + '\n' + read('asm/ntc_lib_cpc.asm') + '\n' + read('asm/ntc_lib_nxt.asm') + '\n' + read('asm/ntc_lib_msx.asm') + '\n' + read('asm/ntc_lib_vdp.asm');
var strLib68k = read('asm/ntc_lib_68k.asm');		// the 68000's keyword library (md)
var strLibM65 = read('asm/ntc_lib_m65.asm');		// the 45GS02's keyword library (m65)
var arrPlat = ['cpc', 'cpcmin', 'cpcfw', 'cpm', 'cyborgos', 'baremetal', 'test', 'zxn', 'msx', 'msxcard', 'msx9990', 'msxdos', 'sc3000', 'colecovision', 'cpc9990', 'cpccard', 'md', 'm65'];
// a platform built on another: ";@base cpm" in asm/ntc_plat_<platform>.asm - its text is its own
// file (the ;@ header, anything of its own) followed by the base's, less the base's ;@ lines it
// has its own of and less the base's sections it has its own of (the same ;## name: its own
// replaces the base's);
// its classes are its own lib/<platform>/*.cls, the base's for any it hasn't got (cyborgos on cpm)
function platText(strPlat)
{
	var strOwn = read('asm/ntc_plat_' + strPlat + '.asm');
	var arrBase = strOwn.match(/^;@base\s+(\w+)\s*$/m);
	var objOwn = {};
	var blnKeep = true;
	if (arrBase)
	{
		strOwn.split(/\r?\n/).forEach(function(strLine)
		{
			var arrM = strLine.match(/^;##\s+(\S+)/);
			var arrK = strLine.match(/^;@(\w+)\s/);
			if (arrM) { objOwn[arrM[1]] = true; }
			if (arrK) { objOwn['@' + arrK[1].toLowerCase()] = true; }
		});
		strOwn += '\n' + platText(arrBase[1]).split(/\r?\n/).filter(function(strLine)
		{
			var arrM = strLine.match(/^;##\s+(\S+)/);
			var arrK = strLine.match(/^;@(\w+)\s/);
			if (arrM) { blnKeep = (objOwn[arrM[1]] === undefined); }
			if (arrK)
			{
				return (objOwn['@' + arrK[1].toLowerCase()] === undefined) && (arrK[1].toLowerCase() !== 'base');	// the base's ;@ keys it has none of its own of
			}
			return blnKeep;
		}).join('\n');
	}
	return strOwn;
}
function platBase(strPlat)
{
	var arrBase = read('asm/ntc_plat_' + strPlat + '.asm').match(/^;@base\s+(\w+)\s*$/m);
	return arrBase ? arrBase[1] : null;
}
// the platform's own classes: lib/<platform>/*.cls
var objClasses = {};
arrPlat.forEach(function(strPlat)
{
	var strDirCls = strDir + 'lib/' + strPlat + '/';
	objClasses[strPlat] = {};
	if (fs.existsSync(strDirCls))
	{
		fs.readdirSync(strDirCls).sort().forEach(function(strFile)
		{
			if (/\.cls$/i.test(strFile))
			{
				objClasses[strPlat][strFile] = fs.readFileSync(strDirCls + strFile, 'utf8');
			}
		});
	}
});
arrPlat.forEach(function(strPlat)
{
	var strBase = platBase(strPlat);
	if (strBase)
	{
		Object.keys(objClasses[strBase] || {}).forEach(function(strFile)
		{
			if (objClasses[strPlat][strFile] === undefined) { objClasses[strPlat][strFile] = objClasses[strBase][strFile]; }
		});
	}
});
var strOut = '// keyword library text from asm/ntc_lib.asm and asm/ntc_plat_*.asm, and the platform\n' +
	'// classes from lib/<platform>/*.cls, used by ntc_compiler.js\n' +
	'// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License\n' +
	'// generated: edit the .asm / .cls files, not this one\n\n' +
	'var NTC_LIB_ASM = ' + JSON.stringify(strLib) + ';\n\n' +
	'var NTC_LIB_ASM_68K = ' + JSON.stringify(strLib68k) + ';\n\n' +
	'var NTC_LIB_ASM_M65 = ' + JSON.stringify(strLibM65) + ';\n\n' +
	'var NTC_PLATFORMS = {\n' + arrPlat.map(function(strPlat) { return '\t' + strPlat + ': ' + JSON.stringify(platText(strPlat)); }).join(',\n') + '\n};\n\n' +
	'var NTC_PLATFORM_CLASSES = ' + JSON.stringify(objClasses, null, '\t') + ';\n\n' +
	'// the keyword library ROM registries (asm/ntc_rom_<platform>.txt, test/genrom.js): Library: ROM\n' +
	'var NTC_ROM_REG = {\n' + arrPlat.filter(function(strPlat) { return fs.existsSync(strDir + 'asm/ntc_rom_' + strPlat + '.txt'); }).map(function(strPlat) { return '\t' + strPlat + ': ' + JSON.stringify(read('asm/ntc_rom_' + strPlat + '.txt')); }).join(',\n') + '\n};\n';
fs.writeFileSync(strDir + 'js/ntc_lib.js', strOut);
console.log('generated js/ntc_lib.js');

// examples: bas/*.bas and project folders -> js/ntc_examples.js
var arrExamples = [
	{ name: 'Syntax guide', files: ['guide.bas'] },
	{ name: 'VB features self test', files: ['vb_test.bas'] },
	{ name: 'VB self test 2 (2 files)', files: ['vb_test2/Main.bas', 'vb_test2/Module2.bas'] },
	{ name: 'VB self test 3 (Enum, With, On GoSub)', files: ['vb_test3.bas'] },
	{ name: 'Long self test (32 bit)', files: ['vb_test_long.bas'] },
	{ name: 'VB self test 4 (array parameters)', files: ['vb_test4.bas'] },
	{ name: 'VB self test 5 (#asm, Inp / Out, library class)', files: ['vb_test5/Main.bas', 'vb_test5/Pool.cls'] },
	{ name: 'VB self test 6 (Byte arrays, ReDim)', files: ['vb_test6.bas'] },
	{ name: 'VB self test 7 (Type and 2D array parameters)', files: ['vb_test7.bas'] },
	{ name: 'VB self test 8 (AddressOf, CallAddr)', files: ['vb_test8.bas'] },
	{ name: 'VB self test 9 (^, IIf, Choose, string functions)', files: ['vb_test9.bas'] },
	{ name: 'VB self test 10 (For Each, Property args)', files: ['vb_test10/Main.bas', 'vb_test10/Bag.cls'] },
	{ name: 'VB self test 11 (asm keyword procedures)', files: ['vb_test11.bas'] },
	{ name: 'VB self test 12 (string lengths: String * n, String Max n)', files: ['vb_test12.bas'] },
	{ name: 'Class project (2 files)', files: ['class_demo/Main.bas', 'class_demo/Counter.cls'] },
	{ name: 'Console classes: StdIO, System (try each platform)', files: ['console_classes.bas'] },
	{ name: 'Files: FileSystem class (try CP/M and CPC firmware)', files: ['files.bas'] },
	{ name: 'Memory map: Memory class RAM pages (CPC)', files: ['memmap.bas'] },
	{ name: 'Lists: a high score table in a linked list', files: ['lists.bas'] },
	{ name: 'Sort timing: 5000 list nodes, turbo and normal', files: ['sorttime.bas'] },
	{ name: 'Command line (System.CommandLine, or ask)', files: ['cmdline.bas'] },
	{ name: '3D wireframe: cube, pyramid, Cobra (cpc, cpcmin, cpcfw)', files: ['cube3d/Main.bas', 'cube3d/Vector3D.cls', 'cube3d/Spin.cls'] },
	{ name: 'Overlays: classes loaded at #4000 (cpcmin, cpcfw, cpm)', files: ['overlays/Main.bas', 'overlays/Level1.cls', 'overlays/Level2.cls'] },
	{ name: 'Pages: classes placed in pages, copies (cpcmin, cpcfw, cpm)', files: ['pages/Main.bas', 'pages/Title.cls', 'pages/Level1.cls', 'pages/Level2.cls', 'pages/Maths.cls', 'pages/Stars.cls', 'pages/Credits.cls', 'pages/Score.cls'] },
	{ name: 'Interrupt classes: Tick at a rate (cpc, cpcmin, cpcfw, zxn)', files: ['interrupts/Main.bas', 'interrupts/Clock.cls', 'interrupts/Star.cls'] },
	{ name: 'Video chip console: scrolling, Mode, Locate (msx, sc3000, cpccard, cpc9990 ...)', files: ['vdp_console.bas'] },
	{ name: 'Keys class: held keys and joysticks (cpc, zxn, msx, sc3000)', files: ['keys_test.bas'] },
	{ name: 'VDP class: V9938 Screen 5, boxes, lines (msx, msxcard, cpc + AMSDAP card)', files: ['vdp_demo.bas'] },
	{ name: 'VDP class: Screen 2 on any TMS9918 (sc3000, msx)', files: ['vdp_screen2.bas'] },
	{ name: 'V9990 class: bit map, boxes, lines (msx9990, cpc9990, msx / cpc + V9990)', files: ['v9990_demo.bas'] },
	{ name: 'JS flavour: a JS program and a JS class (2 files)', files: ['js_demo/Main.js', 'js_demo/Counter.js'] },
	{ name: 'PHP flavour: a PHP program and a PHP class (2 files)', files: ['php_demo/Main.php', 'php_demo/Counter.php'] },
	{ name: 'Locomotive BASIC flavour: a CPC type-in listing', files: ['loco_demo/Main.loc'] },
	{ name: 'Your own StdIO (2 files)', files: ['own_stdio/Main.bas', 'own_stdio/StdIO.cls'] },
	{ name: 'Shell sort - turbo at run time', files: ['shellsort.bas'] },
	{ name: 'Sieve timing - turbo / normal (compare with Small C)', files: ['sievetime.bas'] },
	{ name: '68000 self test (md: the Sega Mega Drive)', files: ['md_test/Main.bas', 'md_test/Counter.cls'] },
	{ name: '45GS02 self test (m65: the MEGA65)', files: ['m65_test/Main.bas', 'm65_test/Counter.cls'] },
	{ name: 'Classic self test', files: ['ntc_test.bas'] },
	{ name: 'Primes (sieve)', files: ['sieve.bas'] },
	{ name: 'Guess the number', files: ['guess.bas'] },
	{ name: 'Numbered GOSUB', files: ['numbered.bas'] }
];
var arrOut = arrExamples.map(function(objEx)
{
	return { name: objEx.name, files: objEx.files.map(function(strFile)
	{
		return { name: strFile.replace(/^.*\//, ''), text: read('bas/' + strFile).replace(/\r\n/g, '\n') };
	}) };
});
fs.writeFileSync(strDir + 'js/ntc_examples.js',
	'// example projects for the NTC BASIC GUI, from the bas folder\n' +
	'// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License\n' +
	'// generated: edit the .bas / .cls files, not this one\n\n' +
	'var NTC_EXAMPLES = ' + JSON.stringify(arrOut, null, '\t') + ';\n');
console.log('generated js/ntc_examples.js');
