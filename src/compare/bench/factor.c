/* Prime factors of 2..1500 by trial division, counted */
#define TOP 1500
int cnt;
bench()
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
main()
{
	puts("go");
	bench();
	printn(cnt);
}
