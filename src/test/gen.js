// regenerates js/ntc_lib.js from the .asm files - scratch tool, not delivered
var fs = require('fs');
var strDir = require('path').join(__dirname, '..') + '/';
function read(f) { return fs.readFileSync(strDir + f, 'utf8'); }
var strLib = read('asm/ntc_lib.asm');
var objPlat = { cpc: read('asm/ntc_plat_cpc.asm') };
var strOut = '// keyword library text from asm/ntc_lib.asm and asm/ntc_plat_*.asm, used by ntc_compiler.js\n' +
	'// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License\n' +
	'// generated: edit the .asm files, not this one\n\n' +
	'var NTC_LIB_ASM = ' + JSON.stringify(strLib) + ';\n\n' +
	'var NTC_PLATFORMS = {\n\tcpc: ' + JSON.stringify(objPlat.cpc) + '\n};\n';
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
	{ name: 'Class project (2 files)', files: ['class_demo/Main.bas', 'class_demo/Counter.cls'] },
	{ name: 'Shell sort - turbo at run time', files: ['shellsort.bas'] },
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
