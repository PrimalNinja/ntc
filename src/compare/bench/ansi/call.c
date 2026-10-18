/* 5000 calls of a function with 2 parameters */
#include <stdio.h>
int s;
int add2(int a, int b)
{
	return a + b;
}
void bench(void)
{
	int i;
	s = 0;
	for (i = 1; i <= 5000; i++)
		s = add2(i, 3);
}
int main(void)
{
	puts("go");
	bench();
	printf("%d\n", s);
	return 0;
}
