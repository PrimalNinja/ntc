// zesshot.js - runs a NEX in ZEsarUX (a Next, no SD card needed) and saves pictures of the screen:
// a quick look that an NTC3D game starts and draws. (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node tools/zesshot.js GAME.NEX [pictures] [seconds apart] [folder]
//
// ZESARUX= the zesarux binary (default: zesarux on the PATH). Its remote protocol on port 10000
// takes the pictures (save-screen: .bmp) and the registers (printed with each one). Default: 3
// pictures 4 seconds apart, into the NEX's folder. ES5.
'use strict';
var fs = require('fs');
var path = require('path');
var net = require('net');
var cp = require('child_process');

var nex = path.resolve(process.argv[2] || '');
var count = parseInt(process.argv[3] || '3', 10);
var gap = parseFloat(process.argv[4] || '4') * 1000;
var out = path.resolve(process.argv[5] || path.dirname(nex));
var zes = process.env.ZESARUX || 'zesarux';

if (!process.argv[2] || !fs.existsSync(nex))
{
	console.log('node zesshot.js GAME.NEX [pictures] [seconds apart] [folder]');
	process.exit(1);
}
var proc = cp.spawn(zes, ['--noconfigfile', '--machine', 'tbblue', '--vo', 'null', '--ao', 'null', '--nowelcomemessage',
	'--enable-remoteprotocol', '--remoteprotocol-port', '10000', '--verbose', '1', '--realvideo', nex],
	{ cwd: path.dirname(zes) === '.' ? process.cwd() : path.dirname(zes), stdio: 'ignore' });
proc.on('error', function(e) { console.log('ZEsarUX did not start (' + e.message + '): set ZESARUX=path/to/zesarux'); process.exit(1); });

var sock = null;
var buf = '';
var waiting = null;

function cmd(str, then)
{
	buf = '';
	waiting = then;
	sock.write(str + '\n');
}
function connect(tries)
{
	sock = net.createConnection(10000, '127.0.0.1');
	sock.setEncoding('latin1');
	sock.on('error', function()
	{
		if (tries > 0) { setTimeout(function() { connect(tries - 1); }, 500); }
		else { console.log('no answer from ZEsarUX on port 10000'); proc.kill(); process.exit(1); }
	});
	sock.on('data', function(d)
	{
		buf += d;
		if (waiting && /command> ?$/.test(buf)) { var w = waiting; waiting = null; w(buf.replace(/command> ?$/, '').trim()); }
	});
	sock.on('connect', function() { setTimeout(function() { shot(1); }, gap); });
}
function shot(n)
{
	var f = path.join(out, path.basename(nex, path.extname(nex)).toLowerCase() + '_' + n + '.bmp');

	cmd('get-registers', function(r)
	{
		console.log(n + ': ' + r.split('\n')[0].substr(0, 60));
		cmd('save-screen ' + f, function()
		{
			setTimeout(function()
			{
				console.log('   ' + f);
				if (n < count) { setTimeout(function() { shot(n + 1); }, gap); }
				else { sock.end(); proc.kill(); process.exit(0); }
			}, 800);
		});
	});
}
setTimeout(function() { connect(20); }, 1500);
