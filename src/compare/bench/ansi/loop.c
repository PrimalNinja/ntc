/* an empty counted loop, 10000 times (volatile: so the loop is not removed) */
#include <stdio.h>
int cnt;
void bench(void)
{
	volatile int i;
	for (i = 1; i <= 10000; i++)
		;
	cnt = i;
}
int main(void)
{
	puts("go");
	bench();
	printf("%d\n", cnt);
	return 0;
}
