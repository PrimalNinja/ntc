// vdu.js - VDU's viewer (ES5: old browsers too): VduScreen draws a screen's display commands
// onto a canvas the way an Amstrad CPC would (MODE 0/1/2, 25 rows, 16 inks from 27 colours,
// windows, text and graphics); VduClient keeps one screen up to date from vdu.php (its pointer
// - the next line it wants -, live or as a replay); VduWall polls for several at once (one ping
// for all, then each screen with new lines drained: asked again at once while there are more).
// Commands (README.md): MODE n, CLS, PRINT text[;], LOCATE x y, PEN i, PAPER i, INK i c,
// BORDER c, WINDOW l r t b, STREAM n, TITLE text, ORIGIN x y, MOVE x y, DRAW x y, PLOT x y,
// GPEN i, CLG [i], BOX x y w h, FILL x y w h, CIRCLE x y r. Anything else is ignored.

// the font: font8x8_basic (Daniel Hepper, public domain) - characters 32-126, 8 bytes each,
// bit 7 the leftmost pixel
var g_arrVduFont = [
	0, 0, 0, 0, 0, 0, 0, 0, 24, 60, 60, 24, 24, 0, 24, 0,
	108, 108, 0, 0, 0, 0, 0, 0, 108, 108, 254, 108, 254, 108, 108, 0,
	48, 124, 192, 120, 12, 248, 48, 0, 0, 198, 204, 24, 48, 102, 198, 0,
	56, 108, 56, 118, 220, 204, 118, 0, 96, 96, 192, 0, 0, 0, 0, 0,
	24, 48, 96, 96, 96, 48, 24, 0, 96, 48, 24, 24, 24, 48, 96, 0,
	0, 102, 60, 255, 60, 102, 0, 0, 0, 48, 48, 252, 48, 48, 0, 0,
	0, 0, 0, 0, 0, 48, 48, 96, 0, 0, 0, 252, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 48, 48, 0, 6, 12, 24, 48, 96, 192, 128, 0,
	124, 198, 206, 222, 246, 230, 124, 0, 48, 112, 48, 48, 48, 48, 252, 0,
	120, 204, 12, 56, 96, 204, 252, 0, 120, 204, 12, 56, 12, 204, 120, 0,
	28, 60, 108, 204, 254, 12, 30, 0, 252, 192, 248, 12, 12, 204, 120, 0,
	56, 96, 192, 248, 204, 204, 120, 0, 252, 204, 12, 24, 48, 48, 48, 0,
	120, 204, 204, 120, 204, 204, 120, 0, 120, 204, 204, 124, 12, 24, 112, 0,
	0, 48, 48, 0, 0, 48, 48, 0, 0, 48, 48, 0, 0, 48, 48, 96,
	24, 48, 96, 192, 96, 48, 24, 0, 0, 0, 252, 0, 0, 252, 0, 0,
	96, 48, 24, 12, 24, 48, 96, 0, 120, 204, 12, 24, 48, 0, 48, 0,
	124, 198, 222, 222, 222, 192, 120, 0, 48, 120, 204, 204, 252, 204, 204, 0,
	252, 102, 102, 124, 102, 102, 252, 0, 60, 102, 192, 192, 192, 102, 60, 0,
	248, 108, 102, 102, 102, 108, 248, 0, 254, 98, 104, 120, 104, 98, 254, 0,
	254, 98, 104, 120, 104, 96, 240, 0, 60, 102, 192, 192, 206, 102, 62, 0,
	204, 204, 204, 252, 204, 204, 204, 0, 120, 48, 48, 48, 48, 48, 120, 0,
	30, 12, 12, 12, 204, 204, 120, 0, 230, 102, 108, 120, 108, 102, 230, 0,
	240, 96, 96, 96, 98, 102, 254, 0, 198, 238, 254, 254, 214, 198, 198, 0,
	198, 230, 246, 222, 206, 198, 198, 0, 56, 108, 198, 198, 198, 108, 56, 0,
	252, 102, 102, 124, 96, 96, 240, 0, 120, 204, 204, 204, 220, 120, 28, 0,
	252, 102, 102, 124, 108, 102, 230, 0, 120, 204, 224, 112, 28, 204, 120, 0,
	252, 180, 48, 48, 48, 48, 120, 0, 204, 204, 204, 204, 204, 204, 252, 0,
	204, 204, 204, 204, 204, 120, 48, 0, 198, 198, 198, 214, 254, 238, 198, 0,
	198, 198, 108, 56, 56, 108, 198, 0, 204, 204, 204, 120, 48, 48, 120, 0,
	254, 198, 140, 24, 50, 102, 254, 0, 120, 96, 96, 96, 96, 96, 120, 0,
	192, 96, 48, 24, 12, 6, 2, 0, 120, 24, 24, 24, 24, 24, 120, 0,
	16, 56, 108, 198, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255,
	48, 48, 24, 0, 0, 0, 0, 0, 0, 0, 120, 12, 124, 204, 118, 0,
	224, 96, 96, 124, 102, 102, 220, 0, 0, 0, 120, 204, 192, 204, 120, 0,
	28, 12, 12, 124, 204, 204, 118, 0, 0, 0, 120, 204, 252, 192, 120, 0,
	56, 108, 96, 240, 96, 96, 240, 0, 0, 0, 118, 204, 204, 124, 12, 248,
	224, 96, 108, 118, 102, 102, 230, 0, 48, 0, 112, 48, 48, 48, 120, 0,
	12, 0, 12, 12, 12, 204, 204, 120, 224, 96, 102, 108, 120, 108, 230, 0,
	112, 48, 48, 48, 48, 48, 120, 0, 0, 0, 204, 254, 254, 214, 198, 0,
	0, 0, 248, 204, 204, 204, 204, 0, 0, 0, 120, 204, 204, 204, 120, 0,
	0, 0, 220, 102, 102, 124, 96, 240, 0, 0, 118, 204, 204, 124, 12, 30,
	0, 0, 220, 118, 102, 96, 240, 0, 0, 0, 124, 192, 120, 12, 248, 0,
	16, 48, 124, 48, 48, 52, 24, 0, 0, 0, 204, 204, 204, 204, 118, 0,
	0, 0, 204, 204, 204, 120, 48, 0, 0, 0, 198, 214, 254, 254, 108, 0,
	0, 0, 198, 108, 56, 108, 198, 0, 0, 0, 204, 204, 204, 124, 12, 248,
	0, 0, 252, 152, 48, 100, 252, 0, 28, 48, 48, 224, 48, 48, 28, 0,
	24, 24, 24, 0, 24, 24, 24, 0, 224, 48, 48, 28, 48, 48, 224, 0,
	118, 220, 0, 0, 0, 0, 0, 0
];

// the CPC's 27 colours: firmware colour n = 9 green + 3 red + blue (each 0, 1, 2: none, half, full)
var g_arrVduColours = [];
(function()
{
	var arrLevel = [0, 128, 255];
	var intI;
	for (intI = 0; intI < 27; intI++)
	{
		g_arrVduColours.push([arrLevel[Math.floor(intI / 3) % 3], arrLevel[Math.floor(intI / 9)], arrLevel[intI % 3]]);
	}
})();

// the CPC's inks at the start: 1 24 20 6 26 0 2 8 10 12 14 16 18 22 1 16; the border 1
var g_arrVduInks = [1, 24, 20, 6, 26, 0, 2, 8, 10, 12, 14, 16, 18, 22, 1, 16];

// VduScreen(objCanvas_a): a screen drawn on a canvas (640 x 400: each of the CPC's 200 rows twice)
// - Reset(), Apply(strLine_a) a command, Hit(intX_a, intY_a) the touch zone at a canvas point
// (CPC coordinates: 0-639, 0-399 from the bottom left), Title(), Border() (a CSS colour)
function VduScreen(objCanvas_a)
{
	var m_objThis = this;
	var m_objCanvas = objCanvas_a;
	var m_objContext = objCanvas_a.getContext('2d');
	var m_objImage = m_objContext.createImageData(640, 400);
	var m_arrPixels = new Uint8Array(640 * 200);   // each pixel's ink (1, 2 or 4 bytes a pixel: the mode's)
	var m_intMode = 1;
	var m_arrInk = [];
	var m_intBorder = 1;
	var m_arrStreams = [];
	var m_intStream = 0;
	var m_intGX = 0;
	var m_intGY = 0;
	var m_intOX = 0;
	var m_intOY = 0;
	var m_intGPen = 1;
	var m_arrZones = [];
	var m_strTitle = '';
	var m_blnDirty = true;
	var m_blnQueued = false;

	// the mode's columns, and a pixel's width (in the 640 of a row)
	function cols()
	{
		return (m_intMode === 0 ? 20 : (m_intMode === 2 ? 80 : 40));
	}

	function pixelWidth()
	{
		return 640 / (cols() * 8);
	}

	// the mode's inks less 1 (a pen past them wraps, as on a CPC: MODE 1's PEN 5 is PEN 1)
	function inks()
	{
		return (m_intMode === 0 ? 15 : (m_intMode === 2 ? 1 : 3));
	}

	function newStream()
	{
		return { l: 1, r: cols(), t: 1, b: 25, x: 1, y: 1, pen: 1, paper: 0 };
	}

	function setMode(intMode_a)
	{
		var intI;
		m_intMode = (intMode_a === 0 || intMode_a === 2 ? intMode_a : 1);
		m_arrStreams = [];
		for (intI = 0; intI < 8; intI++)
		{
			m_arrStreams.push(newStream());
		}
		m_intStream = 0;
		m_intGX = 0;
		m_intGY = 0;
		m_intOX = 0;
		m_intOY = 0;
		m_intGPen = 1;
		m_arrZones = [];
		for (intI = 0; intI < m_arrPixels.length; intI++)
		{
			m_arrPixels[intI] = 0;
		}
		dirty();
	}

	function dirty()
	{
		var fnRequest = window.requestAnimationFrame || function(fnCallback_a) { return window.setTimeout(fnCallback_a, 20); };
		m_blnDirty = true;
		if (!m_blnQueued)
		{
			m_blnQueued = true;
			fnRequest(paint);
		}
	}

	// the pixels onto the canvas, through the inks
	function paint()
	{
		var arrData = m_objImage.data;
		var intRow;
		var intX;
		var intP;
		var intD;
		var arrRGB;
		m_blnQueued = false;
		if (m_blnDirty)
		{
			m_blnDirty = false;
			for (intRow = 0; intRow < 200; intRow++)
			{
				for (intX = 0; intX < 640; intX++)
				{
					arrRGB = g_arrVduColours[m_arrInk[m_arrPixels[intRow * 640 + intX] & 15]];
					intD = (intRow * 2 * 640 + intX) * 4;
					intP = intD + 640 * 4;
					arrData[intD] = arrRGB[0];
					arrData[intD + 1] = arrRGB[1];
					arrData[intD + 2] = arrRGB[2];
					arrData[intD + 3] = 255;
					arrData[intP] = arrRGB[0];
					arrData[intP + 1] = arrRGB[1];
					arrData[intP + 2] = arrRGB[2];
					arrData[intP + 3] = 255;
				}
			}
			m_objContext.putImageData(m_objImage, 0, 0);
			if (m_objCanvas.parentNode)
			{
				m_objCanvas.parentNode.style.backgroundColor = m_objThis.Border();
			}
		}
	}

	// a CPC point (0-639, 0-399 from the bottom left) in ink i: its mode pixel
	function plot(intX_a, intY_a, intInk_a)
	{
		var intW = pixelWidth();
		var intX;
		var intRow = 199 - Math.floor(intY_a / 2);
		var intI;
		if (intX_a >= 0 && intX_a < 640 && intRow >= 0 && intRow < 200)
		{
			intX = Math.floor(intX_a / intW) * intW;
			for (intI = 0; intI < intW; intI++)
			{
				m_arrPixels[intRow * 640 + intX + intI] = intInk_a;
			}
		}
	}

	// a line between CPC points (Bresenham, a mode pixel and a row a step)
	function line(intX0_a, intY0_a, intX1_a, intY1_a, intInk_a)
	{
		var intW = pixelWidth();
		var intX0 = Math.floor(intX0_a / intW);
		var intY0 = Math.floor(intY0_a / 2);
		var intX1 = Math.floor(intX1_a / intW);
		var intY1 = Math.floor(intY1_a / 2);
		var intDX = Math.abs(intX1 - intX0);
		var intDY = -Math.abs(intY1 - intY0);
		var intSX = (intX0 < intX1 ? 1 : -1);
		var intSY = (intY0 < intY1 ? 1 : -1);
		var intErr = intDX + intDY;
		var intE2;
		var blnDone = false;
		var intGuard = 0;
		while (!blnDone && intGuard < 4000)
		{
			plot(intX0 * intW, intY0 * 2, intInk_a);
			if (intX0 === intX1 && intY0 === intY1)
			{
				blnDone = true;
			}
			else
			{
				intE2 = 2 * intErr;
				if (intE2 >= intDY)
				{
					intErr += intDY;
					intX0 += intSX;
				}
				if (intE2 <= intDX)
				{
					intErr += intDX;
					intY0 += intSY;
				}
			}
			intGuard++;
		}
		dirty();
	}

	// a filled box (CPC coordinates: x, y its bottom left)
	function fillBox(intX_a, intY_a, intW_a, intH_a, intInk_a)
	{
		var intY;
		var intX;
		var intStep = pixelWidth();
		for (intY = intY_a; intY < intY_a + intH_a; intY += 2)
		{
			for (intX = intX_a; intX < intX_a + intW_a; intX += intStep)
			{
				plot(intX, intY, intInk_a);
			}
		}
		dirty();
	}

	// a character cell (column, row from 1 on the screen) with a character in pen on paper
	function putChar(intCol_a, intRow_a, intCode_a, intPen_a, intPaper_a)
	{
		var intW = pixelWidth();
		var intX0 = (intCol_a - 1) * 8 * intW;
		var intY0 = (intRow_a - 1) * 8;
		var intGlyph = (intCode_a >= 32 && intCode_a <= 126 ? (intCode_a - 32) * 8 : 0);
		var intR;
		var intB;
		var intByte;
		var intI;
		var intInk;
		if (intRow_a >= 1 && intRow_a <= 25 && intCol_a >= 1 && intCol_a <= cols())
		{
			for (intR = 0; intR < 8; intR++)
			{
				intByte = g_arrVduFont[intGlyph + intR];
				for (intB = 0; intB < 8; intB++)
				{
					intInk = ((intByte & (128 >> intB)) !== 0 ? intPen_a : intPaper_a);
					for (intI = 0; intI < intW; intI++)
					{
						m_arrPixels[(intY0 + intR) * 640 + intX0 + intB * intW + intI] = intInk;
					}
				}
			}
		}
	}

	// the stream's window cleared in its paper
	function clearWindow(objS_a)
	{
		var intW = pixelWidth() * 8;
		var intRow;
		var intX;
		for (intRow = (objS_a.t - 1) * 8; intRow < objS_a.b * 8; intRow++)
		{
			for (intX = (objS_a.l - 1) * intW; intX < objS_a.r * intW; intX++)
			{
				m_arrPixels[intRow * 640 + intX] = objS_a.paper;
			}
		}
		objS_a.x = 1;
		objS_a.y = 1;
		dirty();
	}

	// the stream's window up a line, the bottom one cleared
	function scrollWindow(objS_a)
	{
		var intW = pixelWidth() * 8;
		var intRow;
		var intX;
		var intFrom = (objS_a.l - 1) * intW;
		var intTo = objS_a.r * intW;
		for (intRow = (objS_a.t - 1) * 8; intRow < objS_a.b * 8; intRow++)
		{
			for (intX = intFrom; intX < intTo; intX++)
			{
				m_arrPixels[intRow * 640 + intX] = (intRow + 8 < objS_a.b * 8 ? m_arrPixels[(intRow + 8) * 640 + intX] : objS_a.paper);
			}
		}
	}

	function newLine(objS_a)
	{
		objS_a.x = 1;
		objS_a.y++;
		if (objS_a.y > objS_a.b - objS_a.t + 1)
		{
			scrollWindow(objS_a);
			objS_a.y = objS_a.b - objS_a.t + 1;
		}
	}

	// text at the stream's cursor (wrapping at its window's right, scrolling at its bottom)
	function print(strText_a, blnNewLine_a)
	{
		var objS = m_arrStreams[m_intStream];
		var intI;
		for (intI = 0; intI < strText_a.length; intI++)
		{
			if (objS.x > objS.r - objS.l + 1)
			{
				newLine(objS);
			}
			putChar(objS.l + objS.x - 1, objS.t + objS.y - 1, strText_a.charCodeAt(intI), objS.pen, objS.paper);
			objS.x++;
		}
		if (blnNewLine_a)
		{
			newLine(objS);
		}
		dirty();
	}

	function clamp(intV_a, intMin_a, intMax_a)
	{
		return Math.max(intMin_a, Math.min(intMax_a, intV_a));
	}

	// a colour: a CPC colour 0-26
	function colour(strV_a)
	{
		return clamp(parseInt(strV_a, 10) || 0, 0, 26);
	}

	// the commands' numbers (the words after the first)
	function nums(arrWords_a)
	{
		var arrResult = [];
		var intI;
		for (intI = 1; intI < arrWords_a.length; intI++)
		{
			arrResult.push(parseInt(arrWords_a[intI], 10) || 0);
		}
		while (arrResult.length < 4)
		{
			arrResult.push(0);
		}
		return arrResult;
	}

	this.Reset = function()
	{
		var intI;
		m_arrInk = [];
		for (intI = 0; intI < 16; intI++)
		{
			m_arrInk.push(g_arrVduInks[intI]);
		}
		m_intBorder = 1;
		m_strTitle = '';
		setMode(1);
	};

	this.Title = function()
	{
		return m_strTitle;
	};

	this.Border = function()
	{
		var arrRGB = g_arrVduColours[m_intBorder];
		return 'rgb(' + arrRGB[0] + ',' + arrRGB[1] + ',' + arrRGB[2] + ')';
	};

	// the touch zone at a CPC point ('' none): the last one defined there
	this.Hit = function(intX_a, intY_a)
	{
		var strResult = '';
		var intI;
		var objZ;
		for (intI = 0; intI < m_arrZones.length; intI++)
		{
			objZ = m_arrZones[intI];
			if (intX_a >= objZ.x && intX_a < objZ.x + objZ.w && intY_a >= objZ.y && intY_a < objZ.y + objZ.h)
			{
				strResult = objZ.name;
			}
		}
		return strResult;
	};

	this.Zones = function()
	{
		return m_arrZones.length;
	};

	// a command line
	this.Apply = function(strLine_a)
	{
		var strLine = strLine_a.replace(/^\s+/, '');
		var intSpace = strLine.indexOf(' ');
		var strCmd = (intSpace < 0 ? strLine : strLine.substring(0, intSpace)).toUpperCase();
		var strRest = (intSpace < 0 ? '' : strLine.substring(intSpace + 1));
		var arrWords = strLine.split(/\s+/);
		var arrN = nums(arrWords);
		var objS = m_arrStreams[m_intStream];
		var intI;
		var intX;
		var intY;
		switch (strCmd)
		{
			case 'MODE':
				setMode(arrN[0]);
				break;
			case 'CLS':
				clearWindow(objS);
				break;
			case 'PRINT':
				if (strRest.length > 0 && strRest.charAt(strRest.length - 1) === ';')
				{
					print(strRest.substring(0, strRest.length - 1), false);
				}
				else
				{
					print(strRest, true);
				}
				break;
			case 'LOCATE':
				objS.x = clamp(arrN[0], 1, objS.r - objS.l + 1);
				objS.y = clamp(arrN[1], 1, objS.b - objS.t + 1);
				break;
			case 'PEN':
				objS.pen = arrN[0] & inks();
				break;
			case 'PAPER':
				objS.paper = arrN[0] & inks();
				break;
			case 'INK':
				m_arrInk[clamp(arrN[0], 0, 15)] = colour(arrWords[2]);
				dirty();
				break;
			case 'BORDER':
				m_intBorder = colour(arrWords[1]);
				dirty();
				break;
			case 'STREAM':
				m_intStream = clamp(arrN[0], 0, 7);
				break;
			case 'WINDOW':
				objS.l = clamp(Math.min(arrN[0], arrN[1]), 1, cols());
				objS.r = clamp(Math.max(arrN[0], arrN[1]), 1, cols());
				objS.t = clamp(Math.min(arrN[2], arrN[3]), 1, 25);
				objS.b = clamp(Math.max(arrN[2], arrN[3]), 1, 25);
				objS.x = 1;
				objS.y = 1;
				break;
			case 'TITLE':
				m_strTitle = strRest;
				break;
			case 'ORIGIN':
				m_intOX = arrN[0];
				m_intOY = arrN[1];
				break;
			case 'MOVE':
				m_intGX = arrN[0];
				m_intGY = arrN[1];
				break;
			case 'DRAW':
				line(m_intOX + m_intGX, m_intOY + m_intGY, m_intOX + arrN[0], m_intOY + arrN[1], m_intGPen);
				m_intGX = arrN[0];
				m_intGY = arrN[1];
				break;
			case 'PLOT':
				m_intGX = arrN[0];
				m_intGY = arrN[1];
				plot(m_intOX + m_intGX, m_intOY + m_intGY, m_intGPen);
				dirty();
				break;
			case 'GPEN':
				m_intGPen = arrN[0] & inks();
				break;
			case 'CLG':
				for (intI = 0; intI < m_arrPixels.length; intI++)
				{
					m_arrPixels[intI] = (arrWords.length > 1 ? clamp(arrN[0], 0, 15) : 0);
				}
				dirty();
				break;
			case 'BOX':
				intX = m_intOX + arrN[0];
				intY = m_intOY + arrN[1];
				line(intX, intY, intX + arrN[2], intY, m_intGPen);
				line(intX + arrN[2], intY, intX + arrN[2], intY + arrN[3], m_intGPen);
				line(intX + arrN[2], intY + arrN[3], intX, intY + arrN[3], m_intGPen);
				line(intX, intY + arrN[3], intX, intY, m_intGPen);
				break;
			case 'FILL':
				fillBox(m_intOX + arrN[0], m_intOY + arrN[1], arrN[2], arrN[3], m_intGPen);
				break;
			case 'CIRCLE':
				for (intI = 0; intI < 64; intI++)
				{
					line(m_intOX + arrN[0] + Math.round(arrN[2] * Math.cos(intI * Math.PI / 32)),
						m_intOY + arrN[1] + Math.round(arrN[2] * Math.sin(intI * Math.PI / 32)),
						m_intOX + arrN[0] + Math.round(arrN[2] * Math.cos((intI + 1) * Math.PI / 32)),
						m_intOY + arrN[1] + Math.round(arrN[2] * Math.sin((intI + 1) * Math.PI / 32)), m_intGPen);
				}
				break;
			case 'ZONE':
				if (arrWords.length >= 6)
				{
					m_arrZones.push({ name: arrWords[1], x: arrN[1], y: arrN[2], w: arrN[3], h: arrN[4] });
				}
				else if (arrWords.length === 2 && arrWords[1].toUpperCase() === 'OFF')
				{
					m_arrZones = [];
				}
				break;
			default:
				break;
		}
	};

	this.Reset();
}

// an HTTP GET's text (fnDone_a(strText_a) - '' when it failed)
function vduGet(strURL_a, fnDone_a)
{
	var objXHR = new XMLHttpRequest();
	objXHR.onreadystatechange = function()
	{
		if (objXHR.readyState === 4)
		{
			fnDone_a(objXHR.status === 200 ? objXHR.responseText : '');
		}
	};
	objXHR.open('GET', strURL_a, true);
	objXHR.send();
}

// VduClient(objOptions_a): one screen kept up to date - objOptions_a: url (vdu.php's), id, key
// (writing and the events: '' none), canvas, cbStatus(strText_a), cbTitle(strTitle_a). Live(),
// Replay(intSpeed_a) (lines a 40th of a second), Pause(), Fetch() (lines past the pointer, drained),
// Send(strLines_a), Touch(...), KeyPress(intCode_a), Pointer(), Mode() ('live', 'replay', 'paused')
function VduClient(objOptions_a)
{
	var m_objThis = this;
	var m_objOptions = objOptions_a;
	var m_objScreen = new VduScreen(objOptions_a.canvas);
	var m_intPointer = -1;                   // the next line wanted (-1: join live - from the last MODE)
	var m_intTotal = 0;
	var m_strMode = 'live';
	var m_blnBusy = false;
	var m_arrQueue = [];                     // a replay's lines, waiting their turn
	var m_intSpeed = 4;
	var m_objTimer = null;
	var m_strTitle = '';
	var m_intGen = 0;                        // (a replay started: answers to the asks before it ignored)

	function status()
	{
		if (m_objOptions.cbStatus)
		{
			m_objOptions.cbStatus(m_strMode + ' - line ' + Math.max(0, m_intPointer - m_arrQueue.length) + ' of ' + m_intTotal +
				(m_objScreen.Zones() > 0 ? ' - ' + m_objScreen.Zones() + ' touch zones' : ''));
		}
	}

	function title()
	{
		var strTitle = m_objScreen.Title();
		if (strTitle !== m_strTitle)
		{
			m_strTitle = strTitle;
			if (m_objOptions.cbTitle && strTitle !== '')
			{
				m_objOptions.cbTitle(strTitle);
			}
		}
	}

	// lines past the pointer: drawn (live) or queued (a replay); asked again while there are more
	function fetch()
	{
		var intAsked = m_intPointer;
		var intGen = m_intGen;
		if (!m_blnBusy && m_strMode !== 'paused')
		{
			m_blnBusy = true;
			vduGet(m_objOptions.url + '?a=get&s=' + m_objOptions.id + '&n=' + m_intPointer + '&m=500', function(strText_a)
			{
				var arrLines = strText_a.split('\n');
				var arrHead = arrLines[0].split(' ');
				var intI;
				var blnMore = false;
				if (intGen === m_intGen)
				{
					m_blnBusy = false;
				}
				if (intGen === m_intGen && arrHead[0] === 'ok' && arrHead.length >= 4)
				{
					if (parseInt(arrHead[1], 10) !== intAsked)
					{
						m_objScreen.Reset();         // (joined, or the screen wiped: from where the server says)
						m_arrQueue = [];
					}
					for (intI = 1; intI < arrLines.length; intI++)
					{
						if (arrLines[intI] !== '')
						{
							if (m_strMode === 'replay')
							{
								m_arrQueue.push(arrLines[intI]);
							}
							else
							{
								m_objScreen.Apply(arrLines[intI]);
							}
						}
					}
					m_intPointer = parseInt(arrHead[2], 10);
					m_intTotal = parseInt(arrHead[3], 10);
					blnMore = (m_intPointer < m_intTotal && (m_strMode === 'live' || m_arrQueue.length < 2000));
					title();
				}
				status();
				if (blnMore)
				{
					fetch();                        // (the drain: more at once)
				}
			});
		}
	}

	// a replay's tick: the next lines from the queue (live again at the end)
	function tick()
	{
		var intI;
		if (m_strMode === 'replay')
		{
			for (intI = 0; intI < m_intSpeed && m_arrQueue.length > 0; intI++)
			{
				m_objScreen.Apply(m_arrQueue.shift());
			}
			title();
			if (m_arrQueue.length < 500 && m_intPointer < m_intTotal)
			{
				fetch();
			}
			if (m_arrQueue.length === 0 && m_intPointer >= m_intTotal && !m_blnBusy)
			{
				m_strMode = 'live';
				window.clearInterval(m_objTimer);
				m_objTimer = null;
			}
			status();
		}
	}

	this.Fetch = function()
	{
		fetch();
	};

	this.Pointer = function()
	{
		return m_intPointer;
	};

	this.Mode = function()
	{
		return m_strMode;
	};

	this.ID = function()
	{
		return m_objOptions.id;
	};

	this.Key = function()
	{
		return m_objOptions.key;
	};

	this.Live = function()
	{
		var strWas = m_strMode;
		m_strMode = 'live';
		if (strWas === 'replay')
		{
			while (m_arrQueue.length > 0)
			{
				m_objScreen.Apply(m_arrQueue.shift());
			}
		}
		fetch();
		status();
	};

	// from line 0, intSpeed_a lines a tick
	this.Replay = function(intSpeed_a)
	{
		m_intSpeed = intSpeed_a || 4;
		m_strMode = 'replay';
		m_arrQueue = [];
		m_intPointer = 0;
		m_objScreen.Reset();
		m_blnBusy = false;
		m_intGen++;
		if (m_objTimer === null)
		{
			m_objTimer = window.setInterval(tick, 40);
		}
		fetch();
	};

	this.Pause = function()
	{
		m_strMode = 'paused';
		status();
	};

	// lines to the screen (its key): fnDone_a(strAnswer_a)
	this.Send = function(strLines_a, fnDone_a)
	{
		vduGet(m_objOptions.url + '?a=put&s=' + m_objOptions.id + '&k=' + encodeURIComponent(m_objOptions.key) + '&c=' + encodeURIComponent(strLines_a), function(strText_a)
		{
			fetch();
			if (fnDone_a)
			{
				fnDone_a(strText_a);
			}
		});
	};

	// a tap at a canvas point (its pixels, the canvas shown w x h): a TOUCH event when in a zone
	this.Touch = function(intPX_a, intPY_a, intW_a, intH_a)
	{
		var intX = Math.floor(intPX_a * 640 / intW_a);
		var intY = 399 - Math.floor(intPY_a * 400 / intH_a);
		var strZone = m_objScreen.Hit(intX, intY);
		if (strZone !== '')
		{
			vduGet(m_objOptions.url + '?a=event&s=' + m_objOptions.id + '&e=' + encodeURIComponent('TOUCH ' + strZone + ' ' + intX + ' ' + intY), function() {});
		}
		return strZone;
	};

	// a key (its character code): a KEY event
	this.KeyPress = function(intCode_a)
	{
		vduGet(m_objOptions.url + '?a=event&s=' + m_objOptions.id + '&e=' + encodeURIComponent('KEY ' + intCode_a), function() {});
	};

	status();
}

// VduWall(strURL_a, intEvery_a): the screens' clients polled together - one ping (every intEvery_a
// ms, a random part added so many viewers don't ask at once) names the screens with new lines;
// those are fetched (and drained). Add(objClient_a)
function VduWall(strURL_a, intEvery_a)
{
	var m_arrClients = [];
	var m_strURL = strURL_a;
	var m_intEvery = intEvery_a || 1000;

	function ping()
	{
		var arrPairs = [];
		var intI;
		var objC;
		for (intI = 0; intI < m_arrClients.length; intI++)
		{
			objC = m_arrClients[intI];
			if (objC.Mode() === 'live')
			{
				if (objC.Pointer() < 0)
				{
					objC.Fetch();
				}
				else
				{
					arrPairs.push(objC.ID() + ':' + objC.Pointer());
				}
			}
		}
		if (arrPairs.length > 0)
		{
			vduGet(m_strURL + '?a=ping&w=' + arrPairs.join(','), function(strText_a)
			{
				var arrIDs = strText_a.replace(/\s+$/, '').split(' ');
				var intJ;
				var intK;
				if (arrIDs[0] === 'ok')
				{
					for (intJ = 1; intJ < arrIDs.length; intJ++)
					{
						for (intK = 0; intK < m_arrClients.length; intK++)
						{
							if (m_arrClients[intK].ID() === arrIDs[intJ] && m_arrClients[intK].Mode() === 'live')
							{
								m_arrClients[intK].Fetch();
							}
						}
					}
				}
				window.setTimeout(ping, m_intEvery + Math.floor(Math.random() * m_intEvery / 4));
			});
		}
		else
		{
			window.setTimeout(ping, m_intEvery + Math.floor(Math.random() * m_intEvery / 4));
		}
	}

	this.Add = function(objClient_a)
	{
		m_arrClients.push(objClient_a);
		objClient_a.Fetch();
	};

	window.setTimeout(ping, m_intEvery);
}
