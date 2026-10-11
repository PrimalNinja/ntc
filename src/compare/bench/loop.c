/* an empty counted loop, 10000 times */
int cnt;
bench()
{
	int i;
	for (i = 1; i <= 10000; i++)
		;
	cnt = i;
}
main()
{
	puts("go");
	bench();
	printn(cnt);
}
