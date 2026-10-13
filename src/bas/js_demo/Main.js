//# Option Flavour JS
// The JS flavour: a JS syntax over NTC (ES5 / ES6 subset). It is turned into VB5 text and
// compiled like any other module, so JS and VB files mix in one project.
// //# on a line of its own is an NTC line; //# after code is a type hint.
const MAX = 10;
let total = 0;        //#long
let name = "NTC";
let squares = new Array(MAX);
let c = new Counter();

function square(n)
{
	return n * n;
}

function report(label, value)
{
	console.log(label + ": " + value);
}

for (let i = 0; i < MAX; i++)
{
	squares[i] = square(i);
}
let i = 0;
while (i < MAX)
{
	if (i % 2 == 0)
	{
		total += squares[i];
	}
	i++;
}
console.log(`Hello from ${name.toLowerCase()}`);
report("even squares", total);
c.label = "count";
for (let j = 10; j > 0; j -= 3)
{
	c.add(j);
	print(j, " ");
}
console.log();
console.log(c.describe(), " in ", c.steps, " steps");
