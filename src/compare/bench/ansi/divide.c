/* multiply, divide and remainder, 5000 times */
#include <stdio.h>
int s;
void bench(void)
{
	int i, x;
	s = 0;
	for (i = 1; i <= 5000; i++) {
		x = (i * 5) / 3 + i % 13;
		s = s ^ x;
	}
}
int main(void)
{
	puts("go");
	bench();
	printf("%d\n", s);
	return 0;
}
