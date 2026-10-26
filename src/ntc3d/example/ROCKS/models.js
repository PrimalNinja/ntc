// models.js - ROCKS's models, palette and stars (NTC3D's example game):
//   node ../../tools/e3models.js models.js --png models.png   -> E3Data.cls, build/ROCKS.DAT
// (c) 2026 Cyborg Unicorn Pty Ltd
'use strict';
module.exports = function(M)
{
	var GREY = 0, STEEL = 1, RED = 2, FIRE = 3, GREEN = 4, GOLD = 6, CYAN = 7, WARM = 8, HUD = 13, PLASMA = 12;
	function ramp(a, b, lift) { return { a: a, b: b, lift: lift || 0 }; }
	var ramps = [
		ramp([0, 0, 0], [1, 1, 1]),                         // 0 grey: stars, text
		ramp([0.03, 0.04, 0.08], [0.70, 0.80, 0.95], 0.2),  // 1 steel
		ramp([0.16, 0.01, 0.02], [1.00, 0.50, 0.42], 0.3),  // 2 red
		ramp([0.50, 0.12, 0.00], [1.00, 1.00, 0.70]),       // 3 fire
		ramp([0.02, 0.12, 0.03], [0.60, 1.00, 0.45], 0.3),  // 4 green
		ramp([0.10, 0.02, 0.18], [0.85, 0.60, 1.00], 0.3),  // 5 purple
		ramp([0.20, 0.12, 0.00], [1.00, 0.92, 0.35], 0.3),  // 6 gold
		ramp([0.00, 0.32, 0.40], [0.70, 1.00, 1.00]),       // 7 cyan
		ramp([0.10, 0.07, 0.05], [0.70, 0.60, 0.50], 0.1),  // 8 warm rock
		ramp([0.03, 0.04, 0.06], [0.55, 0.62, 0.72]),       // 9
		ramp([0.20, 0.00, 0.00], [1.00, 0.62, 0.12]),       // 10 amber
		ramp([0.00, 0.05, 0.30], [0.62, 0.85, 1.00], 0.25), // 11 blue
		ramp([0.62, 0.42, 0.00], [1.00, 1.00, 0.92]),       // 12 plasma
		ramp([0.00, 0.00, 0.00], [0.50, 0.96, 0.35]),       // 13 HUD green
		ramp([0.07, 0.05, 0.04], [0.62, 0.56, 0.48], 0.15), // 14
		ramp([0.05, 0.04, 0.08], [0.78, 0.72, 0.88])        // 15
	];
	var PHI = (1 + Math.sqrt(5)) / 2;
	var ICO = [[-1, PHI, 0], [1, PHI, 0], [-1, -PHI, 0], [1, -PHI, 0], [0, -1, PHI], [0, 1, PHI],
		[0, -1, -PHI], [0, 1, -PHI], [PHI, 0, -1], [PHI, 0, 1], [-PHI, 0, -1], [-PHI, 0, 1]];
	function plain(r) { return function() { return r; }; }
	function rock(name, seed, r)
	{
		var rnd = M.random(seed);
		return M.Model(name, ICO.map(function(v) { return M.mul(M.norm(v), 85 + rnd.random() * 40); }), plain(r));
	}
	function octa(name, s, r) { return M.Model(name, [[s, 0, 0], [-s, 0, 0], [0, s, 0], [0, -s, 0], [0, 0, s], [0, 0, -s]], plain(r)); }
	var rockA = rock('rocka', 5, GREY), rockB = rock('rockb', 9, WARM);
	var bolt = M.Model('bolt', [[40, 0, 0], [-40, 0, 0], [0, 40, 0], [0, -40, 0], [0, 0, 70], [0, 0, -70]], plain(PLASMA));
	var shard = M.Model('shard', [[60, -20, -30], [-50, -24, -36], [4, 44, -10], [6, -6, 70]], function(n, c, k) { return (k & 1) ? FIRE : GREY; });
	var fireball = M.Model('fireball', ICO.map(function(v) { return M.mul(M.norm(v), 110); }), plain(FIRE));
	// the beacon: a gold double pyramid that goes round and round
	var beacon = M.Model('beacon', [[0, 120, 0], [0, -120, 0], [70, 0, 0], [-70, 0, 0], [0, 0, 70], [0, 0, -70]],
		function(n) { return n[1] > 0 ? GOLD : CYAN; });
	// the drone: a green spindle that sways its way through
	var drone = M.Model('drone', [[0, 0, 110], [0, 0, -70], [70, 0, 0], [-70, 0, 0], [0, 40, -10], [0, -40, -10]],
		function(n) { return n[2] > 0 ? GREEN : FIRE; });
	// the hunter: a red dart that turns after you and shoots
	var hunter = M.Model('hunter', M.mirrorX([[0, 0, 120], [0, 24, -60], [0, -18, -60], [100, -6, -70]]),
		function(n) { return n[2] < -0.85 ? FIRE : (n[1] > 0 ? RED : STEEL); });
	return {
		ramps: ramps,
		kinds: [M.kind('ROCKA', rockA, octa('rocka_lo', 105, GREY)), M.kind('ROCKB', rockB, octa('rockb_lo', 105, WARM)),
			M.kind('BOLT', bolt, bolt, [50, 50]), M.kind('SHARD', shard), M.kind('FIREBALL', fireball),
			M.kind('BEACON', beacon), M.kind('DRONE', drone), M.kind('HUNTER', hunter, hunter, [60, 30])],
		stars: { n: 64, seed: 3 }
	};
};
