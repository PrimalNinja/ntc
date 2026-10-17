<?php
// VDU's requests (vducore.php: what they are and do)
require(__DIR__ . '/vducore.php');

header('Content-Type: text/plain; charset=ISO-8859-1');
header('Cache-Control: no-store');
header('Access-Control-Allow-Origin: *');

$strAction = param('a');
$strOutput = '';
switch ($strAction)
{
	case 'new':
		$strOutput = actionNew();
		break;
	case 'put':
		$strOutput = actionPut();
		break;
	case 'get':
		$strOutput = actionGet();
		break;
	case 'ping':
		$strOutput = actionPing();
		break;
	case 'list':
		$strOutput = actionList();
		break;
	case 'info':
		$strOutput = actionInfo();
		break;
	case 'wipe':
		$strOutput = actionWipe();
		break;
	case 'event':
		$strOutput = actionEvent();
		break;
	case 'events':
		$strOutput = actionEvents();
		break;
	default:
		$strOutput = 'error a= new, put, get, ping, list, info, wipe, event or events';
		break;
}
echo $strOutput;
