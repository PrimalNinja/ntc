//# Option Flavour JS
// a first JS flavour program
const MAX = 10;
let total = 0;        //#long
let name = "NTC";
let squares = new Array(MAX);

function square(n)
{
	return n * n;
}

function fill()
{
	for (let i = 0; i < MAX; i++)
	{
		squares[i] = square(i);
	}
}

function report(label, value) //#long
{
	console.log(label + ": " + value);
}

fill();
let i = 0;
while (i < MAX)
{
	if (i % 2 == 0)
	{
		total += squares[i];
	}
	else if (i == 7)
	{
		i++;
		continue;
	}
	i++;
}
console.log(`Hello from ${name.toLowerCase()}`, total);
report("len", name.length);
switch (total)
{
	case 120:
		console.log("total is right");
		break;
	default:
		console.log("total is wrong");
		break;
}
for (let j = 10; j > 0; j -= 3)
{
	print(j, " ");
}
console.log();
