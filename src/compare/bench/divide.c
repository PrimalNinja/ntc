/* multiply, divide and remainder, 5000 times */
int s;
bench()
{
	int i, x;
	s = 0;
	for (i = 1; i <= 5000; i++) {
		x = (i * 5) / 3 + i % 13;
		s = s ^ x;
	}
}
main()
{
	puts("go");
	bench();
	printn(s);
}
