// writes build/<platform>/<NAME>.ASM: every example and test program compiled for every
// platform, for build/build.bat to assemble - scratch tool, not delivered
// run after changing the compiler, the library or bas/ (like gen.js)
var fs = require('fs');
var path = require('path');
global.window = global;
var D = path.join(__dirname, '..') + '/';
eval(fs.readFileSync(D + 'js/ntc_lib.js', 'utf8').replace(/^var /gm, 'global.'));
eval(fs.readFileSync(D + 'js/ntc_parser.js', 'utf8').replace(/^var /gm, 'global.').replace('function IFtoPF', 'global.IFtoPF = function IFtoPF').replace('function ntcParse', 'global.ntcParse = function ntcParse'));
eval(fs.readFileSync(D + 'js/ntc_compiler.js', 'utf8').replace('function ntcCompile', 'global.ntcCompile = function ntcCompile'));

// AMSDOS / CP/M names: 8 characters at most
var arrPrograms = [
	{ name: 'GUIDE', files: ['guide.bas'] },
	{ name: 'GUESS', files: ['guess.bas'] },
	{ name: 'SIEVE', files: ['sieve.bas'] },
	{ name: 'SHELSORT', files: ['shellsort.bas'] },
	{ name: 'SIEVETIM', files: ['sievetime.bas'] },
	{ name: 'FILES', files: ['files.bas'] },
	{ name: 'FILESTEP', files: ['filestep.bas'] },
	{ name: 'FILESTPN', files: ['filestpn.bas'] },
	{ name: 'AMSDOS', files: ['amsdos.bas'] },
	{ name: 'MEMMAP', files: ['memmap.bas'] },
	{ name: 'LISTS', files: ['lists.bas'] },
	{ name: 'SORTTIME', files: ['sorttime.bas'] },
	{ name: 'OVERLAYS', files: ['overlays/Main.bas', 'overlays/Level1.cls', 'overlays/Level2.cls'], platforms: ['cpcmin', 'cpcfw', 'cpm'] },
	{ name: 'INTERRUP', files: ['interrupts/Main.bas', 'interrupts/Clock.cls', 'interrupts/Star.cls'], platforms: ['cpc', 'cpcmin'] },
	{ name: 'NUMBERED', files: ['numbered.bas'] },
	{ name: 'NTCTEST', files: ['ntc_test.bas'] },
	{ name: 'VBTEST', files: ['vb_test.bas'] },
	{ name: 'VBTEST2', files: ['vb_test2/Main.bas', 'vb_test2/Module2.bas'] },
	{ name: 'VBTEST3', files: ['vb_test3.bas'] },
	{ name: 'LONGTEST', files: ['vb_test_long.bas'] },
	{ name: 'VBTEST4', files: ['vb_test4.bas'] },
	{ name: 'VBTEST5', files: ['vb_test5/Main.bas', 'vb_test5/Pool.cls'] },
	{ name: 'VBTEST6', files: ['vb_test6.bas'] },
	{ name: 'VBTEST7', files: ['vb_test7.bas'] },
	{ name: 'VBTEST8', files: ['vb_test8.bas'] },
	{ name: 'VBTEST9', files: ['vb_test9.bas'] },
	{ name: 'VBTEST10', files: ['vb_test10/Main.bas', 'vb_test10/Bag.cls'] },
	{ name: 'VBTEST11', files: ['vb_test11.bas'] },
	{ name: 'VBTEST12', files: ['vb_test12.bas'] },
	{ name: 'CLASSDEM', files: ['class_demo/Main.bas', 'class_demo/Counter.cls'] },
	{ name: 'CONSOLE', files: ['console_classes.bas'] },
	{ name: 'OWNSTDIO', files: ['own_stdio/Main.bas', 'own_stdio/StdIO.cls'] }
];
var arrPlatforms = ['cpc', 'cpcmin', 'cpcfw', 'cpm', 'test'];
var intErrors = 0;

arrPlatforms.forEach(function(strPlat)
{
	var strDir = D + 'build/' + strPlat + '/';

	if (!fs.existsSync(strDir))
	{
		fs.mkdirSync(strDir, { recursive: true });
	}
	fs.readdirSync(strDir).forEach(function(strFile)
	{
		if (/\.asm$/i.test(strFile))
		{
			fs.unlinkSync(strDir + strFile);
		}
	});
	arrPrograms.forEach(function(objProg)
	{
		var arrFiles = objProg.files.map(function(strFile)
		{
			return { name: strFile.replace(/^.*\//, ''), text: fs.readFileSync(D + 'bas/' + strFile, 'utf8') };
		});
		var objOpts = { platform: strPlat };
		var objResult = null;

		if (objProg.platforms && (objProg.platforms.indexOf(strPlat) < 0))
		{
			return;		// a program for some platforms only
		}

		if ((strPlat === 'cpc') || (strPlat === 'cpcmin') || (strPlat === 'cpcfw'))
		{
			objOpts.amsdos = objProg.name;		// the assembler writes NAME.BIN with an AMSDOS header
		}
		objResult = ntcCompile((arrFiles.length === 1) ? arrFiles[0].text : arrFiles, objOpts);
		objResult.errors.forEach(function(objErr)
		{
			console.error('ERR ' + strPlat + ' ' + objProg.name + ': ' + (objErr.file || '') + ':' + objErr.line + ': ' + objErr.msg);
			intErrors++;
		});
		fs.writeFileSync(strDir + objProg.name + '.ASM', objResult.asm.replace(/\n/g, '\r\n') + '\r\n');
	});
});
// the Small C sieve, for comparing with SIEVETIM on CP/M (not generated: compare/smallc/SIEVEC.ASM)
fs.writeFileSync(D + 'build/cpm/SIEVEC.ASM', fs.readFileSync(D + 'compare/smallc/SIEVEC.ASM', 'utf8').replace(/\r?\n/g, '\r\n'));
console.log('generated build/ (' + arrPlatforms.length + ' platforms x ' + arrPrograms.length + ' programs)' + (intErrors ? ', ' + intErrors + ' errors' : ''));
