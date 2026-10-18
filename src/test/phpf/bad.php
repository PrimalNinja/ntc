<?php
//# Option Flavour PHP
$a = 1;
do { $a++; } while ($a < 3);
try { $a = 2; } catch (Exception $e) {}
$f = function() { return 1; };
switch ($a) {
 case 1:
  $a = 2;
 case 2:
  $a = 3;
  break;
}
$b = 1.5;
function g() { function h() {} }
