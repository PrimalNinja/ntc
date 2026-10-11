/* Prime factors of 2..1500 by trial division, counted */
#include <stdio.h>
#define TOP 1500
int cnt;
void bench(void)
{
	int i, m, d;
	cnt = 0;
	for (i = 2; i <= TOP; i++) {
		m = i;
		d = 2;
		while (d * d <= m) {
			if (m % d == 0) {
				cnt++;
				m = m / d;
			}
			else
				d++;
		}
		cnt++;
	}
}
int main(void)
{
	puts("go");
	bench();
	printf("%d\n", cnt);
	return 0;
}
