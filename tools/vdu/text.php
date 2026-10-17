<?php
// text.php?s=id[&r=seconds]: a screen as text - for a browser with no canvas or no JavaScript
// (the page refreshes itself, every r seconds: 3). The screen's text commands are played here,
// from its last MODE, onto a grid of characters (MODE's columns x 25 rows), with their pens,
// papers and inks: MODE, CLS, PRINT, LOCATE, PEN, PAPER, INK, BORDER, WINDOW, STREAM, TITLE.
// Graphics are left out.
require(__DIR__ . '/vducore.php');

// the CPC's colours as CSS (firmware colour n = 9 green + 3 red + blue)
function cpcColour($intC_a)
{
	$arrLevel = array('00', '80', 'ff');
	$intC = max(0, min(26, $intC_a));
	return '#' . $arrLevel[intdiv($intC, 3) % 3] . $arrLevel[intdiv($intC, 9)] . $arrLevel[$intC % 3];
}

class TextScreen
{
	public $intCols = 40;
	public $arrChars = array();
	public $arrPens = array();
	public $arrPapers = array();
	public $arrInk = array(1, 24, 20, 6, 26, 0, 2, 8, 10, 12, 14, 16, 18, 22, 1, 16);
	public $intBorder = 1;
	public $strTitle = '';
	public $arrStreams = array();
	public $intStream = 0;

	function __construct()
	{
		$this->setMode(1);
	}

	// the mode's inks less 1 (a pen past them wraps, as on a CPC)
	function inks()
	{
		return ($this->intCols === 20 ? 15 : ($this->intCols === 80 ? 1 : 3));
	}

	function setMode($intMode_a)
	{
		$this->intCols = ($intMode_a === 0 ? 20 : ($intMode_a === 2 ? 80 : 40));
		$this->arrChars = array();
		$this->arrPens = array();
		$this->arrPapers = array();
		for ($intR = 0; $intR < 25; $intR++)
		{
			$this->arrChars[$intR] = array_fill(0, $this->intCols, ' ');
			$this->arrPens[$intR] = array_fill(0, $this->intCols, 1);
			$this->arrPapers[$intR] = array_fill(0, $this->intCols, 0);
		}
		$this->arrStreams = array();
		for ($intI = 0; $intI < 8; $intI++)
		{
			$this->arrStreams[] = array('l' => 1, 'r' => $this->intCols, 't' => 1, 'b' => 25, 'x' => 1, 'y' => 1, 'pen' => 1, 'paper' => 0);
		}
		$this->intStream = 0;
	}

	function clearWindow(&$arrS_a)
	{
		for ($intR = $arrS_a['t'] - 1; $intR < $arrS_a['b']; $intR++)
		{
			for ($intC = $arrS_a['l'] - 1; $intC < $arrS_a['r']; $intC++)
			{
				$this->arrChars[$intR][$intC] = ' ';
				$this->arrPapers[$intR][$intC] = $arrS_a['paper'];
			}
		}
		$arrS_a['x'] = 1;
		$arrS_a['y'] = 1;
	}

	function newLine(&$arrS_a)
	{
		$arrS_a['x'] = 1;
		$arrS_a['y']++;
		if ($arrS_a['y'] > $arrS_a['b'] - $arrS_a['t'] + 1)
		{
			for ($intR = $arrS_a['t'] - 1; $intR < $arrS_a['b']; $intR++)
			{
				for ($intC = $arrS_a['l'] - 1; $intC < $arrS_a['r']; $intC++)
				{
					if ($intR + 1 < $arrS_a['b'])
					{
						$this->arrChars[$intR][$intC] = $this->arrChars[$intR + 1][$intC];
						$this->arrPens[$intR][$intC] = $this->arrPens[$intR + 1][$intC];
						$this->arrPapers[$intR][$intC] = $this->arrPapers[$intR + 1][$intC];
					}
					else
					{
						$this->arrChars[$intR][$intC] = ' ';
						$this->arrPapers[$intR][$intC] = $arrS_a['paper'];
					}
				}
			}
			$arrS_a['y'] = $arrS_a['b'] - $arrS_a['t'] + 1;
		}
	}

	function printText($strText_a, $blnNewLine_a)
	{
		$arrS = &$this->arrStreams[$this->intStream];
		for ($intI = 0; $intI < strlen($strText_a); $intI++)
		{
			if ($arrS['x'] > $arrS['r'] - $arrS['l'] + 1)
			{
				$this->newLine($arrS);
			}
			$intR = $arrS['t'] + $arrS['y'] - 2;
			$intC = $arrS['l'] + $arrS['x'] - 2;
			$strCh = $strText_a[$intI];
			$this->arrChars[$intR][$intC] = (ord($strCh) >= 32 && ord($strCh) <= 126 ? $strCh : ' ');
			$this->arrPens[$intR][$intC] = $arrS['pen'];
			$this->arrPapers[$intR][$intC] = $arrS['paper'];
			$arrS['x']++;
		}
		if ($blnNewLine_a)
		{
			$this->newLine($arrS);
		}
	}

	function apply($strLine_a)
	{
		$strLine = ltrim($strLine_a);
		$intSpace = strpos($strLine, ' ');
		$strCmd = strtoupper($intSpace === false ? $strLine : substr($strLine, 0, $intSpace));
		$strRest = ($intSpace === false ? '' : substr($strLine, $intSpace + 1));
		$arrWords = preg_split('/\s+/', $strLine);
		$arrN = array();
		for ($intI = 1; $intI < 6; $intI++)
		{
			$arrN[] = (isset($arrWords[$intI]) ? (int)$arrWords[$intI] : 0);
		}
		$arrS = &$this->arrStreams[$this->intStream];
		switch ($strCmd)
		{
			case 'MODE':
				$this->setMode($arrN[0]);
				break;
			case 'CLS':
				$this->clearWindow($arrS);
				break;
			case 'PRINT':
				if ($strRest !== '' && substr($strRest, -1) === ';')
				{
					$this->printText(substr($strRest, 0, -1), false);
				}
				else
				{
					$this->printText($strRest, true);
				}
				break;
			case 'LOCATE':
				$arrS['x'] = max(1, min($arrS['r'] - $arrS['l'] + 1, $arrN[0]));
				$arrS['y'] = max(1, min($arrS['b'] - $arrS['t'] + 1, $arrN[1]));
				break;
			case 'PEN':
				$arrS['pen'] = $arrN[0] & $this->inks();
				break;
			case 'PAPER':
				$arrS['paper'] = $arrN[0] & $this->inks();
				break;
			case 'INK':
				$this->arrInk[max(0, min(15, $arrN[0]))] = max(0, min(26, $arrN[1]));
				break;
			case 'BORDER':
				$this->intBorder = max(0, min(26, $arrN[0]));
				break;
			case 'STREAM':
				$this->intStream = max(0, min(7, $arrN[0]));
				break;
			case 'WINDOW':
				$arrS['l'] = max(1, min($this->intCols, min($arrN[0], $arrN[1])));
				$arrS['r'] = max(1, min($this->intCols, max($arrN[0], $arrN[1])));
				$arrS['t'] = max(1, min(25, min($arrN[2], $arrN[3])));
				$arrS['b'] = max(1, min(25, max($arrN[2], $arrN[3])));
				$arrS['x'] = 1;
				$arrS['y'] = 1;
				break;
			case 'TITLE':
				$this->strTitle = $strRest;
				break;
			default:
				break;
		}
	}

	// the grid as HTML: runs of the same pen and paper in a span each
	function html()
	{
		$strResult = '';
		for ($intR = 0; $intR < 25; $intR++)
		{
			$strRun = '';
			$strStyle = '';
			for ($intC = 0; $intC < $this->intCols; $intC++)
			{
				$strNew = 'color:' . cpcColour($this->arrInk[$this->arrPens[$intR][$intC]]) . ';background:' . cpcColour($this->arrInk[$this->arrPapers[$intR][$intC]]);
				if ($strNew !== $strStyle && $strRun !== '')
				{
					$strResult .= '<span style="' . $strStyle . '">' . htmlspecialchars($strRun) . '</span>';
					$strRun = '';
				}
				$strStyle = $strNew;
				$strRun .= $this->arrChars[$intR][$intC];
			}
			$strResult .= '<span style="' . $strStyle . '">' . htmlspecialchars($strRun) . "</span>\n";
		}
		return $strResult;
	}
}

$strID = param('s');
$intRefresh = (param('r') === '' ? 3 : max(1, min(600, (int)param('r'))));
$objScreen = new TextScreen();
$strError = '';
if (!validID($strID) || !is_dir(screenDir($strID)))
{
	$strError = 'No such screen';
}
else
{
	$arrMeta = readMeta($strID);
	$intCount = lineCount($strID, 'log');
	$intJoin = joinPoint($strID);
	if ($intJoin < $intCount)
	{
		$objIdx = fopen(screenDir($strID) . '/log.idx', 'rb');
		$intFrom = lineOffset($objIdx, $intJoin, $intCount, 0);
		fclose($objIdx);
		$objLog = fopen(screenDir($strID) . '/log.txt', 'rb');
		fseek($objLog, $intFrom);
		while (($strLine = fgets($objLog)) !== false)
		{
			$objScreen->apply(rtrim($strLine, "\r\n"));
		}
		fclose($objLog);
	}
	if ($objScreen->strTitle === '')
	{
		$objScreen->strTitle = $arrMeta['title'];
	}
}
header('Content-Type: text/html; charset=ISO-8859-1');
header('Cache-Control: no-store');
$intFont = ($objScreen->intCols === 80 ? 1.1 : ($objScreen->intCols === 20 ? 4.4 : 2.2));
?><!DOCTYPE html>
<html>
<head>
<meta charset="ISO-8859-1">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="<?php echo $intRefresh; ?>">
<title><?php echo htmlspecialchars($strError !== '' ? 'VDU' : $objScreen->strTitle); ?></title>
<style>
body { margin: 0; padding: 8px; background: #000; color: #fff; font-family: monospace; }
.gsScreen { display: inline-block; padding: 2vw; background: <?php echo cpcColour($objScreen->intBorder); ?>; }
.gsScreen pre { margin: 0; font-family: "Courier New", monospace; font-size: <?php echo $intFont; ?>vw; line-height: 1.15; white-space: pre; }
</style>
</head>
<body>
<?php
if ($strError !== '')
{
	echo '<p>' . htmlspecialchars($strError) . '</p>';
}
else
{
	echo '<div class="gsScreen"><pre>' . $objScreen->html() . '</pre></div>';
}
?>
</body>
</html>
