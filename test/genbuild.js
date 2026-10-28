// writes build/<platform>/<NAME>.ASM: every example and test program compiled for every
// platform, for build/build.bat to assemble - scratch tool, not delivered
// run after changing the compiler, the library or bas/ (like gen.js)
var fs = require('fs');
var path = require('path');
global.window = global;
var D = path.join(__dirname, '..', 'src') + '/';
var B = path.join(__dirname, '..', 'build') + '/';
eval(fs.readFileSync(D + 'js/ntc_lib.js', 'utf8').replace(/^var /gm, 'global.'));
eval(fs.readFileSync(D + 'js/ntc_parser.js', 'utf8').replace(/^var /gm, 'global.').replace('function IFtoPF', 'global.IFtoPF = function IFtoPF').replace('function ntcParse', 'global.ntcParse = function ntcParse'));
eval(fs.readFileSync(D + 'js/ntc_compiler.js', 'utf8').replace('function ntcCompile', 'global.ntcCompile = function ntcCompile'));
eval(fs.readFileSync(D + 'js/ntc_flavour_js.js', 'utf8'));
eval(fs.readFileSync(D + 'js/ntc_flavour_php.js', 'utf8'));
eval(fs.readFileSync(D + 'js/ntc_flavour_loco.js', 'utf8'));

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
	{ name: 'CMDLINE', files: ['cmdline.bas'] },
	{ name: 'CITY3D', files: ['city3d/Main.bas', 'city3d/City.cls'], platforms: ['cpcfw'] },
	{ name: 'AUCKLAND', files: ['auckland/Main.bas', 'auckland/S3d.cls'], platforms: ['cpcfw'] },
	{ name: 'CUBE3D', files: ['cube3d/Main.bas', 'cube3d/Vector3D.cls', 'cube3d/Spin.cls'], platforms: ['cpc', 'cpcmin', 'cpcfw', 'cpm'] },
	{ name: 'OVERLAYS', files: ['overlays/Main.bas', 'overlays/Level1.cls', 'overlays/Level2.cls'], platforms: ['cpcmin', 'cpcfw', 'cpm'] },
	{ name: 'PAGES', files: ['pages/Main.bas', 'pages/Title.cls', 'pages/Level1.cls', 'pages/Level2.cls', 'pages/Maths.cls', 'pages/Stars.cls', 'pages/Credits.cls', 'pages/Score.cls'], platforms: ['cpcmin', 'cpcfw', 'cpm', 'zxn'] },
	{ name: 'INTERRUP', files: ['interrupts/Main.bas', 'interrupts/Clock.cls', 'interrupts/Star.cls'], platforms: ['cpc', 'cpcmin', 'cpcfw', 'zxn'] },
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
	{ name: 'OWNSTDIO', files: ['own_stdio/Main.bas', 'own_stdio/StdIO.cls'] },
	{ name: 'JSDEMO', files: ['js_demo/Main.js', 'js_demo/Counter.js'] },
	{ name: 'PHPDEMO', files: ['php_demo/Main.php', 'php_demo/Counter.php'] },
	{ name: 'CHIP8', files: ['chip8/Main.bas'] },
	{ name: 'LOCODEMO', files: ['loco_demo/Main.loc'] }
];
var arrPlatforms = ['cpc', 'cpcmin', 'cpcfw', 'cpm', 'test', 'zxn', 'cpcrom', 'cpcminrom', 'cpcfwrom'];	// ...rom: Library: ROM (needs NTCCPC / NTCMIN / NTCFW.ROM); zxn: NAME.NEX
var intErrors = 0;

arrPlatforms.forEach(function(strPlat)
{
	var strDir = B + strPlat + '/';

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
		var strReal = strPlat.replace(/rom$/, '');
		var objOpts = { platform: strReal };
		var objResult = null;

		if (strPlat !== strReal)
		{
			objOpts.library = 'rom';
		}
		if (objProg.platforms && (objProg.platforms.indexOf(strReal) < 0))
		{
			return;		// a program for some platforms only
		}

		objOpts.name = objProg.name;			// page files: NAME.001 ...; zxn: NAME.NEX
		if ((strReal === 'cpc') || (strReal === 'cpcmin') || (strReal === 'cpcfw'))
		{
			objOpts.amsdos = objProg.name;		// the assembler writes NAME.BIN with an AMSDOS header
		}
		objResult = ntcCompile(((arrFiles.length === 1) && !/\.(js|loc)$/i.test(arrFiles[0].name)) ? arrFiles[0].text : arrFiles, objOpts);
		objResult.errors.forEach(function(objErr)
		{
			console.error('ERR ' + strPlat + ' ' + objProg.name + ': ' + (objErr.file || '') + ':' + objErr.line + ': ' + objErr.msg);
			intErrors++;
		});
		fs.writeFileSync(strDir + objProg.name + '.ASM', objResult.asm.replace(/\n/g, '\r\n') + '\r\n');
	});
});
// the Small C sieve, for comparing with SIEVETIM on CP/M (not generated: compare/smallc/SIEVEC.ASM)
fs.writeFileSync(B + 'cpm/SIEVEC.ASM', fs.readFileSync(D + 'compare/smallc/SIEVEC.ASM', 'utf8').replace(/\r?\n/g, '\r\n'));
console.log('generated build/ (' + arrPlatforms.length + ' platforms x ' + arrPrograms.length + ' programs)' + (intErrors ? ', ' + intErrors + ' errors' : ''));
