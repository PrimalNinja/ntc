// run_zes.js - the Next FileSystem test on real NextZXOS in ZEsarUX: the card made by sdimage.py
// (autoexec .nexload /NTC.NEX) booted, the program's results read from memory at arr_r (the .sym).
//   ZESARUX=/path/zesarux node run_zes.js /tmp/zxnfs.mmc
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'use strict';
var cp = require('child_process'), fs = require('fs'), path = require('path'), os = require('os');
var Zrcp = require('/home/claude/cos/tools/regress/zrcp.js');
var ZES = process.env.ZESARUX || '/home/claude/zesarux/src/zesarux';
var strImg = process.argv[2] || '/tmp/zxnfs.mmc';
var strSym = fs.readFileSync(path.join(__dirname, 'Main.sym'), 'latin1');
function sym(strName_a) { var m = strSym.match(new RegExp('^' + strName_a + ': EQU 0x([0-9A-Fa-f]+)', 'm')); return parseInt(m[1], 16); }
function sleep(ms_a) { return new Promise(function(r_a) { setTimeout(r_a, ms_a); }); }
(async function()
{
	var strTmp = fs.mkdtempSync(path.join(os.tmpdir(), 'zxnfs-'));
	fs.copyFileSync(strImg, path.join(strTmp, 'card.mmc'));
	cp.spawnSync('pkill', ['-x', 'zesarux']);
	var zes = cp.spawn(ZES, ['--noconfigfile', '--machine', 'tbblue', '--vo', 'null', '--ao', 'null', '--nowelcomemessage',
		'--enable-remoteprotocol', '--remoteprotocol-port', '10000', '--verbose', '1', '--realvideo', '--enable-mmc',
		'--enable-divmmc-ports', '--enable-divmmc-paging', '--mmc-file', path.join(strTmp, 'card.mmc'), '--mmc-no-persistent-writes'], { cwd: path.dirname(ZES), stdio: 'ignore' });	// ZEsarUX finds its ROMs beside itself
	await sleep(6000);
	var z = new Zrcp(10000); await sleep(500);
	// NextZXOS's first boot on a fresh card: the video-mode test (Enter), the welcome (Space), then the autoexec
	var down = function(k) { return z.cmd('send-keys-event ' + k + ' 1'); }, up = function(k) { return z.cmd('send-keys-event ' + k + ' 0'); };
	var tap = async function(k) { await down(k); await sleep(200); await up(k); await sleep(400); };
	await sleep(30000); await tap(129); await sleep(12000); await tap(128); await sleep(25000);
	await z.cmd('set-memory-zone 0');
	var intA = sym('arr_r'), arrR = [], intI = 0;
	// the program's RAM: pages 16-21 at #0000-#BFFF (8K MMU pages: physical 0x40000 + page * 8192 in ZEsarUX's map)
	for (intI = 0; intI < 16; intI++)
	{
		var a = intA + intI * 2, s = await z.cmd('read-memory ' + (0x40000 + (16 + (a >> 13)) * 8192 + (a & 0x1FFF)) + ' 2');
		var m = s.match(/([0-9A-Fa-f]{2})\s*([0-9A-Fa-f]{2})/); arrR.push(m ? parseInt(m[1], 16) + 256 * parseInt(m[2], 16) : -9999);
	}
	var intNm = 0xBC00, strNm = '', intK = 0;
	if (process.env.ZXNFS_DEBUG !== '1') { intNm = -1; }
	for (intK = 0; intK < (intNm < 0 ? 0 : 24); intK++) { var a2 = intNm + intK, s2 = await z.cmd('read-memory ' + (0x40000 + (16 + (a2 >> 13)) * 8192 + (a2 & 0x1FFF)) + ' 1'); strNm += s2.trim().slice(0, 2) + ' '; }
	if (intNm >= 0) { console.log('BNAME #BB40:', strNm); }
	var strTr = '';
	for (intK = 0; intK < (intNm < 0 ? 0 : 16); intK++) { var a3 = 0xBA00 + intK, s3 = await z.cmd('read-memory ' + (0x40000 + (16 + (a3 >> 13)) * 8192 + (a3 & 0x1FFF)) + ' 1'); strTr += s3.trim().slice(0, 2) + ' '; }
	if (intNm >= 0) { console.log('trampoline at BA00:', strTr); }
	var mB = strSym.match(/^(asm_\d+_\d+_n_dc_bc): EQU 0x([0-9A-Fa-f]+)/m), mT = strSym.match(/^(asm_\d+_\d+_n_dc_tramp): EQU 0x([0-9A-Fa-f]+)/m), strCells = '', intOff = parseInt(mB[2], 16) - parseInt(mT[2], 16);
	for (intK = 0; intK < (intNm < 0 ? 0 : 14); intK++) { var a4 = 0xBA00 + intOff + intK, s4 = await z.cmd('read-memory ' + (0x40000 + (16 + (a4 >> 13)) * 8192 + (a4 & 0x1FFF)) + ' 1'); strCells += s4.trim().slice(0, 2) + ' '; }
	if (intNm >= 0) { console.log('cells bc de ix a l cy m0 m1 sp:', strCells); }
	await z.cmd('set-memory-zone -1');
	for (intI = 0; intI < 16; intI++) { if (arrR[intI] > 32767) { arrR[intI] -= 65536; } }
	console.log('r():', arrR.join(' '));
	var ok = true;
	function check(strN_a, blnOk_a, v_a) { console.log((blnOk_a ? 'ok   ' : 'FAIL ') + strN_a + (blnOk_a ? '' : ': ' + v_a)); if (!blnOk_a) { ok = false; } }
	check('the program ran (r0 = 1234)', arrR[0] === 1234, arrR[0]);
	check('Save: OK', arrR[1] === 0, arrR[1]);
	check('Size: 100', arrR[2] === 100, arrR[2]);
	check('Load: 100 bytes', arrR[3] === 100, arrR[3]);
	check('the bytes came back', arrR[4] === 100, arrR[4]);
	check('Open: a handle', arrR[5] > 0, arrR[5]);
	check('Seek 50: OK', arrR[6] === 0, arrR[6]);
	check('ReadByte after the seek: 82', arrR[7] === 82, arrR[7]);
	check('Eof: not at the end', arrR[8] === 0, arrR[8]);
	check('ReadLine from 0: 10 characters', arrR[10] === 10, arrR[10]);
	check('Close: OK', arrR[11] === 0, arrR[11]);
	check('Exists: yes', arrR[12] === -1, arrR[12]);
	check('Rename: OK', arrR[13] === 0, arrR[13]);
	check('Delete: OK', arrR[14] === 0, arrR[14]);
	check('gone after the delete, and DirEntry(0) gave an entry', arrR[15] === 5678, 'r15 (the error) = ' + arrR[15]);
	z.sock.end(); zes.kill(); process.exit(ok ? 0 : 1);

})();
