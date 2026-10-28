// builds a ROMDISC (read-only files in ROMs: the CPC FileSystem's volume R) - scratch tool
//   node genromdisc.js outdir file [file ...]   (8.3 names: the file's own name, in capitals)
// writes outdir/NTCDISC.ROM (and NTCDISC2.ROM ... when the files need more than one ROM)
var fs = require('fs');
var path = require('path');
var strDir = path.join(__dirname, '..', 'src') + '/';
global.window = global;
eval(fs.readFileSync(strDir + 'js/ntc_compiler.js', 'utf8').replace('function ntcRomDisc', 'global.ntcRomDisc = function ntcRomDisc'));
var arrArgs = process.argv.slice(2);
var strOut = path.resolve(arrArgs.shift() || '.') + '/';
var arrFiles = arrArgs.map(function(strF) { return { name: path.basename(strF), bytes: Array.prototype.slice.call(fs.readFileSync(strF)) }; });
var objRes = ntcRomDisc(arrFiles);
if (objRes.errors.length > 0) { console.error(objRes.errors.join('\n')); process.exit(1); }
if (!fs.existsSync(strOut)) { fs.mkdirSync(strOut, { recursive: true }); }
for (var intK = 2; intK <= 9; intK++) { if (fs.existsSync(strOut + 'NTCDISC' + intK + '.ROM')) { fs.unlinkSync(strOut + 'NTCDISC' + intK + '.ROM'); } }
objRes.roms.forEach(function(arrR, intI) { fs.writeFileSync(strOut + objRes.files[intI], Buffer.from(arrR)); });
console.log('ROMDISC: ' + arrFiles.length + ' files, ' + objRes.files.join(', '));
