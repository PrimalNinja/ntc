/* Sieve of Eratosthenes, primes below 8000, a char flag per number */
#define TOP 8000
char flags[8001];
int cnt;
bench()
{
	int i, j;
	for (i = 2; i <= TOP; i++)
		flags[i] = 1;
	cnt = 0;
	for (i = 2; i <= TOP; i++) {
		if (flags[i] == 1) {
			cnt++;
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
	puts("go");
	bench();
	printn(cnt);
}
