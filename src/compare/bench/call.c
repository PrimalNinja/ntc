/* 5000 calls of a function with 2 parameters */
int s;
add2(a, b)
int a, b;
{
	return a + b;
}
bench()
{
	int i;
	s = 0;
	for (i = 1; i <= 5000; i++)
		s = add2(i, 3);
}
main()
{
	puts("go");
	bench();
	printn(s);
}
