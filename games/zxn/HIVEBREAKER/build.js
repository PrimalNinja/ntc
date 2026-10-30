// build.js - builds HIVEBREAKER: the models, then the IDE project, the assembler and the NEX file
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node build.js [path to NTC's src folder]
//
// NTC's src folder (the one with ntc3d/ in it) is looked for in the argument, then NTC_SRC, then
// ../../.. (the game in src/ntc3d/example/HIVEBREAKER, next to ROCKS). The game can be anywhere
// when NTC's src is given: game.json's "framework" is set to NTC3D's folder from here.
//
// 1. NTC3D's model tool: models.js -> E3Data.cls and build/HIVEBRK.DAT (and a picture, models.png)
// 2. NTC3D's build tool: HIVEBRK.json (the project for NTC BASIC's IDE: ntc.html, Open...),
//    build/HIVEBRK.asm and, with sjasmplus on the PATH (or SJASMPLUS=...), build/HIVEBRK.NEX
'use strict';
var m_objFs = require('fs');
var m_objPath = require('path');
var m_objCp = require('child_process');

var m_strHere = __dirname;
var m_strCfgFile = m_objPath.join(m_strHere, 'game.json');
var m_objCfg = JSON.parse(m_objFs.readFileSync(m_strCfgFile, 'utf8'));
var m_strSrc = '';
var m_strRel = '';
var m_intRc = 1;

function findSrc()
{
	var arrTries, intI, strFound;
	arrTries = [process.argv[2], process.env.NTC_SRC, m_objPath.join(m_strHere, '..', '..', '..')];
	strFound = '';
	for (intI = 0; intI < arrTries.length; intI++)
	{
		if (strFound === '' && arrTries[intI] && m_objFs.existsSync(m_objPath.join(arrTries[intI], 'ntc3d', 'tools', 'e3models.js')))
		{
			strFound = m_objPath.resolve(arrTries[intI]);
		}
	}
	return strFound;
}

function run(strTool_a, arrArgs_a)
{
	var objRes;
	objRes = m_objCp.spawnSync('node', [m_objPath.join(m_strSrc, 'ntc3d', 'tools', strTool_a)].concat(arrArgs_a), { cwd: m_strHere, stdio: 'inherit' });
	return objRes.status;
}

m_strSrc = findSrc();
if (m_strSrc === '')
{
	console.log('NTC\'s src folder (the one with ntc3d/ in it) not found: node build.js <path to it>, or set NTC_SRC');
}
else
{
	m_strRel = m_objPath.relative(m_strHere, m_objPath.join(m_strSrc, 'ntc3d')).split(m_objPath.sep).join('/');
	if (m_objCfg.framework !== m_strRel)
	{
		m_objCfg.framework = m_strRel;
		m_objFs.writeFileSync(m_strCfgFile, JSON.stringify(m_objCfg));
	}
	m_intRc = run('e3models.js', ['models.js', '.', '--name', m_objCfg.name, '--png', 'models.png']);
	if (m_intRc === 0)
	{
		m_intRc = run('build.js', ['.', m_strSrc]);
	}
}
process.exit(m_intRc);
