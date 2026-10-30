// models.js - HIVEBREAKER's models, palette, stars and skyline (for NTC3D's model tool):
//   node ntc3d/tools/e3models.js models.js . --name HIVEBRK --png models.png
//   -> E3Data.cls and build/HIVEBRK.DAT
// Every model is a convex solid (or a compound of them); a model unit is 2^size world units
// (the game's Spawn says the size). Ground things stand on y = 0: their middle is half their height up.
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'use strict';
module.exports = function (M)
{
	// the palette's ramps: 16 ramps of 16 shades, darkest to lightest (a, b), lift lightens the middle
	var m_intGREY = 0, m_intSTEEL = 1, m_intRED = 2, m_intFIRE = 3, m_intGREEN = 4, m_intVIOLET = 5;
	var m_intGOLD = 6, m_intCYAN = 7, m_intDUST = 8, m_intCONC = 9, m_intBLUE = 10, m_intNIGHT = 11;
	var m_intPLASMA = 12, m_intHUD = 13, m_intMETAL = 14, m_intMAGENTA = 15;

	function ramp(arrA_a, arrB_a, dblLift_a)
	{
		return { a: arrA_a, b: arrB_a, lift: dblLift_a || 0 };
	}

	var m_arrRamps = [
		ramp([0, 0, 0], [1, 1, 1]),                         // 0 grey: stars, text
		ramp([0.04, 0.05, 0.10], [0.72, 0.80, 0.92], 0.2),  // 1 steel
		ramp([0.16, 0.01, 0.02], [1.00, 0.46, 0.38], 0.3),  // 2 red
		ramp([0.50, 0.12, 0.00], [1.00, 1.00, 0.70]),       // 3 fire
		ramp([0.02, 0.12, 0.04], [0.58, 1.00, 0.45], 0.3),  // 4 green
		ramp([0.07, 0.03, 0.15], [0.74, 0.50, 0.95], 0.2),  // 5 violet (the far mountains, haze)
		ramp([0.20, 0.12, 0.00], [1.00, 0.92, 0.35], 0.3),  // 6 gold
		ramp([0.00, 0.30, 0.40], [0.70, 1.00, 1.00]),       // 7 cyan
		ramp([0.10, 0.05, 0.04], [0.62, 0.34, 0.22], 0.05), // 8 dust (the ground: rust)
		ramp([0.07, 0.07, 0.09], [0.70, 0.67, 0.62], 0.1),  // 9 concrete
		ramp([0.02, 0.05, 0.20], [0.55, 0.75, 1.00], 0.2),  // 10 blue (the robots)
		ramp([0.00, 0.00, 0.05], [0.28, 0.42, 0.84], 0.1),  // 11 night blue (the sky)
		ramp([0.62, 0.42, 0.00], [1.00, 1.00, 0.92]),       // 12 plasma
		ramp([0.00, 0.00, 0.00], [0.50, 0.96, 0.35]),       // 13 HUD green
		ramp([0.03, 0.03, 0.05], [0.40, 0.42, 0.52], 0.1),  // 14 dark metal
		ramp([0.22, 0.02, 0.18], [1.00, 0.55, 0.88], 0.2)   // 15 pink (the power-ups)
	];

	var m_dblPHI = (1 + Math.sqrt(5)) / 2;
	var m_arrICO = [[-1, m_dblPHI, 0], [1, m_dblPHI, 0], [-1, -m_dblPHI, 0], [1, -m_dblPHI, 0], [0, -1, m_dblPHI], [0, 1, m_dblPHI],
		[0, -1, -m_dblPHI], [0, 1, -m_dblPHI], [m_dblPHI, 0, -1], [m_dblPHI, 0, 1], [-m_dblPHI, 0, -1], [-m_dblPHI, 0, 1]];

	// every face one ramp
	function plain(intRamp_a)
	{
		return function ()
		{
			return intRamp_a;
		};
	}

	// a box as a model: [x0, x1, y0, y1, z0, z1]
	function bx(strName_a, arrBox_a, intRamp_a)
	{
		return M.Model(strName_a, M.box(arrBox_a[0], arrBox_a[1], arrBox_a[2], arrBox_a[3], arrBox_a[4], arrBox_a[5]), plain(intRamp_a));
	}

	// a box with a different colour on its front (+z) face: a visor, a chest light
	function bxf(strName_a, arrBox_a, intRamp_a, intFront_a)
	{
		return M.Model(strName_a, M.box(arrBox_a[0], arrBox_a[1], arrBox_a[2], arrBox_a[3], arrBox_a[4], arrBox_a[5]), function (arrN_a)
		{
			return arrN_a[2] > 0.5 ? intFront_a : intRamp_a;
		});
	}

	// an eight sided prism whose flat faces look along the axes (apothem intApo_a), from y0 to y1
	function oct(intApo_a, intY0_a, intY1_a)
	{
		var arrP = [], intI, dblR, dblA;
		dblR = intApo_a / Math.cos(Math.PI / 8);
		for (intI = 0; intI < 8; intI++)
		{
			dblA = (intI + 0.5) * Math.PI / 4;
			arrP.push([Math.round(dblR * Math.cos(dblA)), intY0_a, Math.round(dblR * Math.sin(dblA))]);
			arrP.push([Math.round(dblR * Math.cos(dblA)), intY1_a, Math.round(dblR * Math.sin(dblA))]);
		}
		return arrP;
	}

	// an icosahedron of radius intR_a
	function ico(intR_a)
	{
		return m_arrICO.map(function (arrV_a)
		{
			return M.mul(M.norm(arrV_a), intR_a);
		});
	}

	// a tapered block: a box at the bottom (arrB_a: x0, x1, y, z0, z1) and another at the top (arrT_a), one colour
	// for its sides, one for its front (+z) face, one for its top
	function tp(strName_a, arrB_a, arrT_a, intSide_a, intFront_a, intTop_a)
	{
		var arrP = [
			[arrB_a[0], arrB_a[2], arrB_a[3]], [arrB_a[1], arrB_a[2], arrB_a[3]], [arrB_a[0], arrB_a[2], arrB_a[4]], [arrB_a[1], arrB_a[2], arrB_a[4]],
			[arrT_a[0], arrT_a[2], arrT_a[3]], [arrT_a[1], arrT_a[2], arrT_a[3]], [arrT_a[0], arrT_a[2], arrT_a[4]], [arrT_a[1], arrT_a[2], arrT_a[4]]
		];
		return M.Model(strName_a, arrP, function (arrN_a)
		{
			var intR = intSide_a;
			if (arrN_a[1] > 0.7)
			{
				intR = intTop_a;
			}
			else if (arrN_a[2] > 0.5)
			{
				intR = intFront_a;
			}
			return intR;
		});
	}

	// a trooper: tapered legs with feet, a V shaped chest, a head with a visor, shoulder pads, arms (8 parts, 64 points)
	function trooper(strName_a, intBody_a, intLimb_a, intHead_a, intLight_a, intPad_a)
	{
		return M.Compound(strName_a, [
			tp(strName_a + 'LL', [-17, -4, -52, -10, 12], [-14, -6, -16, -7, 7], intLimb_a, intLimb_a, intLimb_a),
			tp(strName_a + 'LR', [4, 17, -52, -10, 12], [6, 14, -16, -7, 7], intLimb_a, intLimb_a, intLimb_a),
			tp(strName_a + 'T', [-14, 14, -18, -10, 10], [-24, 24, 26, -12, 12], intBody_a, intHead_a, intBody_a),
			bxf(strName_a + 'H', [-10, 10, 28, 46, -9, 9], intHead_a, intLight_a),
			bx(strName_a + 'PL', [-36, -22, 14, 28, -10, 10], intPad_a),
			bx(strName_a + 'PR', [22, 36, 14, 28, -10, 10], intPad_a),
			bx(strName_a + 'AL', [-32, -24, -22, 12, -5, 5], intLimb_a),
			bx(strName_a + 'AR', [24, 32, -22, 12, -5, 5], intLimb_a)
		], { eye: [0, 5, 3000], views: 1 });
	}

	var m_objGrunt = trooper('grunt', m_intBLUE, m_intMETAL, m_intSTEEL, m_intCYAN, m_intCONC);
	var m_objGruntLo = tp('grunt_lo', [-16, 16, -52, -10, 12], [-30, 30, 40, -12, 12], m_intBLUE, m_intSTEEL, m_intSTEEL);

	// the hulk: a big grey brute: thick legs, a huge chest, a small head sunk between big shoulder blocks, long arms
	var m_objHulk = M.Compound('hulk', [
		tp('hulkLL', [-32, -8, -56, -14, 16], [-26, -10, -20, -12, 12], m_intMETAL, m_intMETAL, m_intMETAL),
		tp('hulkLR', [8, 32, -56, -14, 16], [10, 26, -20, -12, 12], m_intMETAL, m_intMETAL, m_intMETAL),
		tp('hulkT', [-30, 30, -20, -14, 14], [-52, 52, 40, -18, 18], m_intCONC, m_intSTEEL, m_intCONC),
		bxf('hulkH', [-12, 12, 42, 58, -9, 9], m_intMETAL, m_intBLUE),
		bx('hulkPL', [-68, -46, 24, 50, -14, 14], m_intSTEEL),
		bx('hulkPR', [46, 68, 24, 50, -14, 14], m_intSTEEL),
		bx('hulkAL', [-66, -48, -36, 22, -11, 11], m_intMETAL),
		bx('hulkAR', [48, 66, -36, 22, -11, 11], m_intMETAL)
	], { eye: [0, 5, 3000], views: 1 });
	var m_objHulkLo = tp('hulk_lo', [-34, 34, -56, -16, 16], [-68, 68, 56, -18, 18], m_intCONC, m_intSTEEL, m_intCONC);

	// the scout: a flying saucer with a glass dome and a gun slung under it
	var m_arrScout = [[0, 16, 0], [0, -14, 0], [0, 0, 76]];
	var m_intI;
	for (m_intI = 0; m_intI < 8; m_intI++)
	{
		m_arrScout.push([Math.round(60 * Math.cos(m_intI * Math.PI / 4)), 0, Math.round(60 * Math.sin(m_intI * Math.PI / 4))]);
	}
	var m_objScout = M.Compound('scout', [
		M.Model('scoutD', m_arrScout, function (arrN_a)
		{
			var intR = m_intSTEEL;
			if (arrN_a[2] > 0.5)
			{
				intR = m_intBLUE;
			}
			else if (arrN_a[1] < -0.3)
			{
				intR = m_intMETAL;
			}
			return intR;
		}),
		M.Model('scoutG', [[18, 12, 18], [-18, 12, 18], [18, 12, -18], [-18, 12, -18], [0, 34, 0]], plain(m_intCYAN)),
		bx('scoutU', [-6, 6, -26, -12, 8, 46], m_intMETAL)
	], { eye: [0, 40, 3000], views: 1 });
	var m_objScoutLo = M.Model('scout_lo', [[50, 0, 0], [-50, 0, 0], [0, 10, 0], [0, -10, 0], [0, 0, 50], [0, 0, -50]], plain(m_intSTEEL));

	// the tank-bot: a tracked robot tank: two track pods, a sloped hull, a round turret and a barrel
	var m_objTank = M.Compound('tankbot', [
		bx('tbTL', [-46, -28, -30, 8, -36, 36], m_intMETAL),
		bx('tbTR', [28, 46, -30, 8, -36, 36], m_intMETAL),
		tp('tbH', [-26, 26, -10, -30, 30], [-20, 20, 14, -22, 26], m_intBLUE, m_intSTEEL, m_intSTEEL),
		M.Model('tbU', oct(16, 14, 28), function (arrN_a)
		{
			return arrN_a[1] > 0.7 ? m_intMETAL : m_intSTEEL;
		}),
		bx('tbB', [-3, 3, 18, 25, 10, 54], m_intMETAL)
	], { eye: [0, 40, 3000], views: 1 });
	var m_objTankLo = tp('tankbot_lo', [-46, 46, -30, -36, 36], [-30, 30, 30, -26, 30], m_intBLUE, m_intSTEEL, m_intSTEEL);

	// the orb: a hovering sphere with two side fins and a cone below
	var m_objOrb = M.Compound('orb', [
		M.Model('orbS', ico(40), function (arrN_a, arrC_a, intK_a)
		{
			return (intK_a & 1) ? m_intBLUE : m_intSTEEL;
		}),
		bx('orbL', [-72, -46, -4, 4, -6, 6], m_intMETAL),
		bx('orbR', [46, 72, -4, 4, -6, 6], m_intMETAL),
		M.Model('orbC', [[0, -56, 0], [14, -32, 14], [-14, -32, 14], [14, -32, -14], [-14, -32, -14]], plain(m_intMETAL))
	], { eye: [0, 40, 3000], views: 1 });
	var m_objOrbLo = M.Model('orb_lo', ico(40), plain(m_intBLUE));

	// the electrode: a tall spinning crystal. Touch it and it goes off
	var m_objElect = M.Model('electrode', [[0, 70, 0], [0, -70, 0], [16, 0, 16], [-16, 0, 16], [16, 0, -16], [-16, 0, -16]], function (arrN_a, arrC_a, intK_a)
	{
		return (intK_a & 1) ? m_intBLUE : m_intSTEEL;
	});

	// the power-ups: a pod, pink or green, hovering and turning
	function pod(strName_a, intRamp_a)
	{
		var arrP = [[0, 46, 0], [0, -46, 0]], intI;
		for (intI = 0; intI < 6; intI++)
		{
			arrP.push([Math.round(26 * Math.cos(intI * Math.PI / 3)), 0, Math.round(26 * Math.sin(intI * Math.PI / 3))]);
		}
		return M.Model(strName_a, arrP, plain(intRamp_a));
	}
	var m_objPodP = pod('podp', m_intMAGENTA);
	var m_objPodG = pod('podg', m_intGREEN);

	// the hive: a tiered octagonal tower with a beacon on top; its door is on the -z side (a separate object)
	var m_objHive = M.Compound('hive', [
		M.Model('hivePl', oct(100, -50, -40), plain(m_intMETAL)),
		M.Model('hiveBd', oct(90, -40, 30), function (arrN_a)
		{
			return arrN_a[1] > 0.8 ? m_intMETAL : m_intCONC;
		}),
		M.Model('hiveT2', oct(64, 30, 52), function (arrN_a)
		{
			return arrN_a[1] > 0.8 ? m_intMETAL : m_intSTEEL;
		}),
		M.Model('hiveBc', [[10, 52, 10], [-10, 52, 10], [10, 52, -10], [-10, 52, -10], [0, 82, 0]], function (arrN_a, arrC_a, intK_a)
		{
			return (intK_a & 1) ? m_intRED : m_intFIRE;
		})
	], { eye: [0, 5, 3000], views: 1 });
	var m_objHiveLo = M.Model('hive_lo', oct(90, -50, 52), function (arrN_a)
	{
		return arrN_a[1] > 0.8 ? m_intMETAL : m_intCONC;
	});

	var m_objDoor = bx('door', [-20, 20, -24, 24, -3, 3], m_intCYAN);
	var m_objDoorX = bx('doorx', [-20, 20, -24, 24, -3, 3], m_intMETAL);

	// scenery: a pylon, a silo
	var m_objPylon = M.Model('pylon', [[20, -80, 20], [-20, -80, 20], [20, -80, -20], [-20, -80, -20], [7, 70, 7], [-7, 70, 7], [7, 70, -7], [-7, 70, -7], [0, 98, 0]], function (arrN_a)
	{
		return arrN_a[1] > 0.5 ? m_intBLUE : m_intMETAL;
	});
	var m_arrSilo = oct(52, -40, 36);
	m_arrSilo.push([0, 62, 0]);
	var m_objSilo = M.Model('silo', m_arrSilo, function (arrN_a)
	{
		return arrN_a[1] > 0.3 ? m_intMETAL : m_intCONC;
	});

	// the reactor core: a hot jewel
	var m_objCore = M.Model('core', ico(64), function (arrN_a, arrC_a, intK_a)
	{
		return (intK_a & 1) ? m_intPLASMA : m_intFIRE;
	});

	// a gun turret: a base, a dome and a barrel (it turns to look at you)
	var m_arrDome = oct(22, -6, 8);
	m_arrDome.push([0, 24, 0]);
	var m_objTurret = M.Compound('turret', [
		M.Model('turB', oct(30, -30, -6), plain(m_intMETAL)),
		M.Model('turD', m_arrDome, plain(m_intSTEEL)),
		bx('turG', [-4, 4, 0, 8, 10, 64], m_intMETAL)
	], { eye: [0, 40, 3000], views: 1 });
	var m_objTurretLo = M.Model('turret_lo', oct(30, -30, 24), plain(m_intSTEEL));

	// the warden: indestructible, it comes for you if you stay too long
	var m_objWarden = M.Model('warden', ico(66), function (arrN_a, arrC_a, intK_a)
	{
		return (intK_a & 1) ? m_intBLUE : m_intMETAL;
	});

	var m_objPillar = M.Model('pillar', oct(30, -60, 60), function (arrN_a)
	{
		return Math.abs(arrN_a[1]) > 0.8 ? m_intMETAL : m_intCONC;
	});

	var m_objBolt = M.Model('bolt', [[30, 0, 0], [-30, 0, 0], [0, 30, 0], [0, -30, 0], [0, 0, 64], [0, 0, -64]], function (arrN_a, arrC_a, intK_a)
	{
		return (intK_a & 1) ? m_intRED : m_intPLASMA;
	});
	var m_objShard = M.Model('shard', [[60, -20, -30], [-50, -24, -36], [4, 44, -10], [6, -6, 70]], function (arrN_a, arrC_a, intK_a)
	{
		return (intK_a & 1) ? m_intFIRE : m_intRED;
	});
	var m_objFireball = M.Model('fireball', ico(110), plain(m_intFIRE));

	// the skyline: a ring of mountains (bearing x, z (127 = 1), half width, height, colours, top), far ones lighter
	var m_arrSky = [];
	var m_objRnd = M.random(5);
	var m_intK, m_dblA, m_intS, m_intC;
	for (m_intK = 0; m_intK < 15; m_intK++)
	{
		m_dblA = m_intK * 2 * Math.PI / 15 + 0.2;
		m_intS = 3 + (m_intK & 1);
		m_intC = (m_intVIOLET * 16 + m_intS) + (m_intVIOLET * 16 + m_intS + 1) * 256;
		m_arrSky.push([Math.round(127 * Math.sin(m_dblA)), Math.round(127 * Math.cos(m_dblA)), 22 + Math.floor(m_objRnd.random() * 30),
			8 + Math.floor(m_objRnd.random() * 26), m_intC, (m_intK % 3) === 0 ? 3 : 0]);
	}

	return {
		ramps: m_arrRamps,
		kinds: [
			M.kind('GRUNT', m_objGrunt, m_objGruntLo, [34, 50]),
			M.kind('HULK', m_objHulk, m_objHulkLo, [66, 58]),
			M.kind('SCOUT', m_objScout, m_objScoutLo, [58, 20]),
			M.kind('TANK', m_objTank, m_objTankLo, [46, 30]),
			M.kind('ORB', m_objOrb, m_objOrbLo, [60, 56]),
			M.kind('ELECT', m_objElect, m_objElect, [20, 70]),
			M.kind('PODP', m_objPodP, m_objPodP, [30, 46]),
			M.kind('PODG', m_objPodG, m_objPodG, [30, 46]),
			M.kind('HIVE', m_objHive, m_objHiveLo, [92, 82]),
			M.kind('DOOR', m_objDoor, m_objDoor, [24, 24]),
			M.kind('DOORX', m_objDoorX, m_objDoorX, [24, 24]),
			M.kind('PYLON', m_objPylon, m_objPylon, [20, 98]),
			M.kind('SILO', m_objSilo, m_objSilo, [52, 62]),
			M.kind('CORE', m_objCore, m_objCore, [64, 64]),
			M.kind('TURRET', m_objTurret, m_objTurretLo, [30, 30]),
			M.kind('WARDEN', m_objWarden, m_objWarden, [66, 66]),
			M.kind('PILLAR', m_objPillar, m_objPillar, [32, 60]),
			M.kind('BOLT', m_objBolt, m_objBolt, [50, 50]),
			M.kind('SHARD', m_objShard),
			M.kind('FIREB', m_objFireball)
		],
		stars: { n: 64, seed: 11 },
		skyline: m_arrSky
	};
};
