#include <stdio.h>

void function1() {
	printf("%d\n", 1);
}

void function2() {
	printf("%d\n", 2);
}

void function3() {
	printf("%d\n", 1);
}

int main() {
	function1();
	function2();
	function3();
	return 0;
}
