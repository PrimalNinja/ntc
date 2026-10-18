//# Option Flavour JS
class Counter
{
	total = 0;          //#long
	#steps = 0;
	label = "";

	add(n)
	{
		this.total += n;
		this.#bump();
	}

	#bump()
	{
		this.#steps++;
	}

	get steps()
	{
		return this.#steps;
	}

	describe()
	{
		return this.label + "=" + this.total;
	}
}
