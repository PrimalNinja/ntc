// regenerates js/ntc_lib.js from the .asm files - scratch tool, not delivered
var fs = require('fs');
var strDir = require('path').join(__dirname, '..') + '/';
function read(f) { return fs.readFileSync(strDir + f, 'utf8'); }
var strLib = read('asm/ntc_lib.asm');
var arrPlat = ['cpc', 'cpcmin', 'cpcfw', 'cpm', 'test'];
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
var strOut = '// keyword library text from asm/ntc_lib.asm and asm/ntc_plat_*.asm, and the platform\n' +
	'// classes from lib/<platform>/*.cls, used by ntc_compiler.js\n' +
	'// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License\n' +
	'// generated: edit the .asm / .cls files, not this one\n\n' +
	'var NTC_LIB_ASM = ' + JSON.stringify(strLib) + ';\n\n' +
	'var NTC_PLATFORMS = {\n' + arrPlat.map(function(strPlat) { return '\t' + strPlat + ': ' + JSON.stringify(read('asm/ntc_plat_' + strPlat + '.asm')); }).join(',\n') + '\n};\n\n' +
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
	{ name: 'Interrupt classes: Tick at a rate (cpc, cpcmin, cpcfw)', files: ['interrupts/Main.bas', 'interrupts/Clock.cls', 'interrupts/Star.cls'] },
	{ name: 'JS flavour: a JS program and a JS class (2 files)', files: ['js_demo/Main.js', 'js_demo/Counter.js'] },
	{ name: 'Locomotive BASIC flavour: a CPC type-in listing', files: ['loco_demo/Main.loc'] },
	{ name: 'Your own StdIO (2 files)', files: ['own_stdio/Main.bas', 'own_stdio/StdIO.cls'] },
	{ name: 'Shell sort - turbo at run time', files: ['shellsort.bas'] },
	{ name: 'Sieve timing - turbo / normal (compare with Small C)', files: ['sievetime.bas'] },
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
