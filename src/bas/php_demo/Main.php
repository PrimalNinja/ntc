<?php
//# Option Flavour PHP
// The PHP flavour: a PHP syntax over NTC (a PHP 5.4 subset). It is turned into VB5 text and
// compiled like any other module, so PHP and VB files mix in one project.
// //# on a line of its own is an NTC line; //# after code is a type hint.
//# Option PressAnyKeyOnEnd "Press a key"
const MAX = 10;
$total = 0;        //#long
$name = "NTC";
$squares = array_fill(0, MAX, 0);
$c = new Counter();

function square($n)
{
	return $n * $n;
}

function report($label, $value)
{
	echo $label . ": " . $value . "\n";
}

for ($i = 0; $i < MAX; $i++)
{
	$squares[$i] = square($i);
}
$i = 0;
while ($i < MAX)
{
	if ($i % 2 == 0)
	{
		$total += $squares[$i];
	}
	$i++;
}
echo "Hello from " . strtolower($name) . "\n";
report("even squares", $total);
$c->label = "count";
for ($j = 10; $j > 0; $j -= 3)
{
	$c->add($j);
	print $j . " ";
}
echo "\n";
echo $c->describe() . " in " . $c->steps() . " steps\n";
