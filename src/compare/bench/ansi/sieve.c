/* Sieve of Eratosthenes, primes below 8000, a char flag per number */
#include <stdio.h>
#define TOP 8000
unsigned char flags[TOP + 1];
int cnt;
void bench(void)
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
int main(void)
{
	puts("go");
	bench();
	printf("%d\n", cnt);
	return 0;
}
