/* Shell sort of 2001 numbers (0..1023, from x = (x * 13 + 7) & 1023) */
#define N 2000
int arr[2001];
fill()
{
	int i, x;
	x = 1;
	for (i = 0; i <= N; i++) {
		x = (x * 13 + 7) & 1023;
		arr[i] = x;
	}
}
bench()
{
	int gap, i, j, t;
	gap = N / 2;
	while (gap > 0) {
		for (i = gap; i <= N; i++) {
			t = arr[i];
			j = i;
			while (j >= gap) {
				if (arr[j - gap] <= t)
					break;
				arr[j] = arr[j - gap];
				j = j - gap;
			}
			arr[j] = t;
		}
		gap = gap / 2;
	}
}
main()
{
	fill();
	puts("go");
	bench();
	printn(arr[0]);
	printn(arr[1000]);
	printn(arr[N]);
}
