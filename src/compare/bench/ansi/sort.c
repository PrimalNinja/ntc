/* Shell sort of 2001 numbers (0..1023, from x = (x * 13 + 7) & 1023) */
#include <stdio.h>
#define N 2000
int arr[N + 1];
void fill(void)
{
	int i, x;
	x = 1;
	for (i = 0; i <= N; i++) {
		x = (x * 13 + 7) & 1023;
		arr[i] = x;
	}
}
void bench(void)
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
int main(void)
{
	fill();
	puts("go");
	bench();
	printf("%d %d %d\n", arr[0], arr[1000], arr[N]);
	return 0;
}
