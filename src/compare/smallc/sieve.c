/* Sieve of Eratosthenes - primes below 8000, 5 passes.
   Plain Small C, the same work as bas/sievetime.bas (a char flag per number).
   Start the stopwatch as you press a key, stop it at "Done". */
#define TOP 8000
#define PASSES 5

char flags[8001];
int count;

sieve()
{
	int i, j;
	for (i = 2; i <= TOP; i++)
		flags[i] = 1;
	count = 0;
	for (i = 2; i <= TOP; i++) {
		if (flags[i] == 1) {
			count++;
			j = i + i;
			while (j <= TOP) {
				flags[j] = 0;
				j = j + i;
			}
		}
	}
}

main()
{
	int p;
	puts("Small C sieve: primes below 8000, 5 passes");
	puts("Press a key to start");
	getkey();
	for (p = 0; p < PASSES; p++)
		sieve();
	puts("Done - stop the stopwatch");
	printn(count);
	puts("Press a key");
	getkey();
}
