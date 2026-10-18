<?php
//# Option Flavour PHP
// a first PHP flavour program
const MAX = 10;
$total = 0;            //#long
$name = "NTC";
$squares = array_fill(0, MAX, 0);

function square($n) { return $n * $n; }

function fill()
{
	for ($i = 0; $i < MAX; $i++)
	{
		$squares[$i] = square($i);
	}
}

function report($label, $value) //#long
{
	echo $label . ": " . $value . "\n";
}

fill();
$i = 0;
while ($i < MAX)
{
	if ($i % 2 == 0)
	{
		$total += $squares[$i];
	}
	elseif ($i == 7)
	{
		$i++;
		continue;
	}
	$i++;
}
echo "Hello from " . strtolower($name) . " " . $total . "\n";
report("len", strlen($name));
switch ($total)
{
	case 120: echo "total is right\n"; break;
	default: echo "total is wrong\n"; break;
}
for ($j = 10; $j > 0; $j -= 3) { echo $j . " "; }
echo "\n";
