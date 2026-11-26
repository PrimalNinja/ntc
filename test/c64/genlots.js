// genlots.js - writes a big NTC BASIC program in two lots for the c64reu tests: each lot is a
// class of N Subs of filler, each adding its own number to the lot's total, all called from
// the lot's Run. Each lot's thread is far past 32K, so its pieces are in two REU banks.
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//   node genlots.js N outdir      (prints the total each lot should print)
'use strict';
var fs = require('fs');
var intN = parseInt(process.argv[2], 10) || 250;
var strDir = process.argv[3];
function cls(strName_a, intMul_a)
{
	var arrL = ["' made by test/c64/genlots.js: " + intN + " Subs", 'Private mSum As Long', 'Private mX As Integer', 'Private mRuns As Integer', ''];
	var intI = 0, intJ = 0;

	for (intI = 1; intI <= intN; intI++)
	{
		arrL.push('Private Sub S' + intI + '()');
		for (intJ = 0; intJ < 11; intJ++) { arrL.push('  mX = mX + ' + (intJ + 1) + ' : mX = mX - ' + (intJ + 1)); }
		arrL.push('  mSum = mSum + ' + (intI * intMul_a));
		arrL.push('End Sub');
	}
	arrL.push('Public Sub Run()');
	arrL.push('  mRuns = mRuns + 1');
	for (intI = 1; intI <= intN; intI++) { arrL.push('  S' + intI); }
	arrL.push('  Print "' + strName_a.toLowerCase() + '="; mSum; " x="; mX; " runs="; mRuns');
	arrL.push('End Sub');
	fs.writeFileSync(strDir + '/' + strName_a + '.cls', arrL.join('\n') + '\n');
}
cls('BigA', 1);
cls('BigB', 3);
fs.writeFileSync(strDir + '/Main.bas', ['Option Lot A = BigA', 'Option Lot B = BigB', 'BigA.Run', 'BigB.Run', 'BigA.Run', 'Print "pieces="; System.Pieces()', 'End'].join('\n') + '\n');
console.log(intN * (intN + 1) / 2);
