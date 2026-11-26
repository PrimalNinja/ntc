// genbig.js - writes a big NTC BASIC program for the c64reu tests: N Subs of filler, each adding
// its own number to a total, all called twice from the main program. The thread is far past
// what a PRG can hold, so it must be built with c64build.js --split.
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//   node genbig.js N out.bas      (prints the total the program should print)
'use strict';
var intN = parseInt(process.argv[2], 10) || 300;
var arrL = ["' made by test/c64/genbig.js: " + intN + " Subs", 'Dim l As Long, x As Integer, i As Integer', ''];
var intI = 0, intJ = 0;
for (intI = 1; intI <= intN; intI++)
{
	arrL.push('Sub S' + intI + '()');
	for (intJ = 0; intJ < 11; intJ++) { arrL.push('  x = x + ' + (intJ + 1) + ' : x = x - ' + (intJ + 1)); }
	arrL.push('  l = l + ' + intI);
	arrL.push('End Sub');
}
arrL.push('For i = 1 To 2');
for (intI = 1; intI <= intN; intI++) { arrL.push('  S' + intI); }
arrL.push('Next');
arrL.push('Print "pieces="; System.Pieces(); " total="; l; " x="; x');
arrL.push('End');
require('fs').writeFileSync(process.argv[3], arrL.join('\n') + '\n');
console.log(intN * (intN + 1));
