// run_zes.js - the Loader test on real NextZXOS in ZEsarUX: a card made by nextcard.py booted, a
// picture of the screen saved (BMP).   ZESARUX=/path/zesarux [ZRCP=/path/zrcp.js] node run_zes.js CARD.mmc OUT.bmp
// The screen must read: len200310116 / none-2 / big-8 / bad-4 / low20038. (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'use strict';
var fs = require('fs'), path = require('path'), cp = require('child_process'), os = require('os');
var Zrcp = require(process.env.ZRCP || '../../../CYBORGOS/tools/regress/zrcp.js');   // CyborgOS's ZEsarUX remote-control client
var ZES = process.env.ZESARUX;
var sleep = function(ms_a) { return new Promise(function(r_a) { setTimeout(r_a, ms_a); }); };
(async function()
{
	var strTmp = fs.mkdtempSync(path.join(os.tmpdir(), 'nxld'));
	fs.copyFileSync(process.argv[2], path.join(strTmp, 'card.mmc'));
	cp.spawnSync('pkill', ['-x', 'zesarux']);
	await sleep(1000);
	var zes = cp.spawn(ZES, ['--noconfigfile', '--machine', 'tbblue', '--vo', 'null', '--ao', 'null', '--nowelcomemessage',
		'--enable-remoteprotocol', '--remoteprotocol-port', '10000', '--verbose', '1', '--realvideo', '--enable-mmc',
		'--enable-divmmc-ports', '--enable-divmmc-paging', '--mmc-file', path.join(strTmp, 'card.mmc'), '--mmc-no-persistent-writes'],
		{ cwd: path.dirname(ZES), stdio: 'ignore' });
	await sleep(4500);
	var z = new Zrcp(10000);
	await sleep(30000); await z.cmd('send-keys-event 129 1'); await sleep(200); await z.cmd('send-keys-event 129 0');
	await sleep(12000); await z.cmd('send-keys-event 128 1'); await sleep(200); await z.cmd('send-keys-event 128 0');
	await sleep(25000);
	await z.cmd('save-screen ' + process.argv[3]); await sleep(1500);
	zes.kill('SIGKILL');
	process.exit(0);
})();
