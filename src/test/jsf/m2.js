//# Option Flavour JS
//# Option Explicit
let c = new Counter();
let n = 0;
c.label = "js";
for (let i = 1; i <= 4; i++)
{
	c.add(i);
}
//# Turbo On
n = peek(0x40);
/* #asm
			ld hl, ({n})
			inc hl
			ld ({n}), hl
*/
//# Turbo Off
console.log(c.describe(), " ", c.steps, " ", n > 0);
let s = "abcdef";
console.log(s.substr(1, 3), s.indexOf("d"), s.charCodeAt(0), String.fromCharCode(72), s.slice(-2));
console.log(Math.abs(-5), 7 % 3, 2 ** 5, 1 << 4, 0x10, true ? "yes" : "no");
