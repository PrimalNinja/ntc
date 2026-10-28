<?php
//# Option Flavour PHP
//# Option Explicit
$c = new Counter();
$n = 0;
$c->label = "php";
for ($i = 1; $i <= 4; $i++)
{
	$c->add($i);
}
//# Turbo On
$n = peek(0x40);
/* #asm
			ld hl, ({n})
			inc hl
			ld ({n}), hl
*/
//# Turbo Off
echo $c->describe() . " " . $c->steps() . " " . ($n > 0 ? "1" : "0") . "\n";
$s = "abcdef";
echo substr($s, 1, 3) . " " . strpos($s, "d") . " " . ord($s) . " " . chr(72) . "\n";
echo abs(-5) . " " . (7 % 3) . " " . (2 ** 5) . " " . (1 << 4) . " " . 0x10 . "\n";
