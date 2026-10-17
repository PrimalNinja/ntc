<?php
// dumb.php?s=id[&r=seconds][&n=lines]: a screen as a rolling log - for the dumbest browser (a
// Nintendo DS / 3DS): no positions, no colours, no script. Each PRINT's text is a line at the
// bottom (PRINT text; - no new line - carries on the same line, until a MODE, CLS, LOCATE,
// WINDOW or STREAM); everything else (positions, colours, graphics ...) is left out. The last n lines (24), the newest at the bottom; the page
// refreshes itself every r seconds (5)
require(__DIR__ . '/vducore.php');

$strID = param('s');
$intRefresh = (param('r') === '' ? 5 : max(1, min(600, (int)param('r'))));
$intShow = (param('n') === '' ? 24 : max(1, min(500, (int)param('n'))));
$arrShown = array();
$strTitle = 'VDU';
$strError = '';
if (!validID($strID) || !is_dir(screenDir($strID)))
{
	$strError = 'No such screen';
}
else
{
	$arrMeta = readMeta($strID);
	$strTitle = $arrMeta['title'];
	$strFile = screenDir($strID) . '/log.txt';
	$intSize = filesize($strFile);
	$intRead = min($intSize, 65536);         // (the log's tail: enough for the lines shown)
	$objLog = fopen($strFile, 'rb');
	fseek($objLog, $intSize - $intRead);
	$strTail = ($intRead > 0 ? fread($objLog, $intRead) : '');
	fclose($objLog);
	$arrLines = explode("\n", $strTail);
	if ($intRead < $intSize)
	{
		array_shift($arrLines);              // (the first one cut short)
	}
	$strCurrent = null;
	foreach ($arrLines as $strLine)
	{
		$strLine = ltrim($strLine);
		if (strtoupper(substr($strLine, 0, 5)) === 'PRINT' && (strlen($strLine) === 5 || $strLine[5] === ' '))
		{
			$strText = (string)substr($strLine, 6);
			$blnGo = true;
			if ($strText !== '' && substr($strText, -1) === ';')
			{
				$strText = substr($strText, 0, -1);
				$blnGo = false;
			}
			$strCurrent = ($strCurrent === null ? '' : $strCurrent) . $strText;
			if ($blnGo)
			{
				$arrShown[] = $strCurrent;
				$strCurrent = null;
			}
		}
		elseif (strtoupper(substr($strLine, 0, 6)) === 'TITLE ')
		{
			$strTitle = substr($strLine, 6);
		}
		elseif ($strCurrent !== null && preg_match('/^(MODE|CLS|LOCATE|WINDOW|STREAM)\b/i', $strLine))
		{
			$arrShown[] = $strCurrent;           // (a line left open - PRINT text; - ends where the text moves)
			$strCurrent = null;
		}
	}
	if ($strCurrent !== null)
	{
		$arrShown[] = $strCurrent;
	}
	$arrShown = array_slice($arrShown, -$intShow);
}
header('Content-Type: text/html; charset=ISO-8859-1');
header('Cache-Control: no-store');
echo '<html><head><meta http-equiv="refresh" content="' . $intRefresh . '">';
echo '<meta name="viewport" content="width=device-width"><title>' . htmlspecialchars($strTitle) . '</title></head>';
echo '<body bgcolor="#000000" text="#ffff00"><b>' . htmlspecialchars($strTitle) . '</b><br><tt>';
if ($strError !== '')
{
	echo htmlspecialchars($strError);
}
foreach ($arrShown as $strLine)
{
	echo htmlspecialchars($strLine) . "<br>\n";
}
echo '</tt><a name="end"></a></body></html>';
