
void print_char(char c)
{
	*(char*)0x8003 = c;
}


void print_int(int v)
{
	char buf[10];
	int i;
	int tmp;

	if (v == 0) {
		print_char('0');
		return;
	}

	if (v < 0) {
		print_char('-');
		v = -v;
	}

	i = 0;
	while (v > 0) {
		tmp = v / 10;
		buf[i++] = v - tmp*10 + '0';
		v = tmp;
	}

	for (i--; i >= 0; i--)
		print_char(buf[i]);
}

void print_string(const char *str)
{
	char c;

	while ((c = *str++)) 
		print_char(c);
}


int main()
{
	int i;
	int fib_n = -1;
	int fib_np1 = 1;
	int fib_np2;

	print_string("Hello, world!\n");
	print_string("What you see is the simulation of a BLIF netlist implementing a processor,\n");
	print_string("which is itself executing a helloworld in the simulation.\n\n");

	print_string("Here are the first 26 Fibonacci numbers:\n");
	for (i = 0; i < 26; i++) {
		fib_np2 = fib_n + fib_np1;
		fib_n   = fib_np1;
		fib_np1 = fib_np2;
		print_int(i);
		print_string(" -> ");
		print_int(fib_np2);
		print_char('\n');
	}

	return 0;
}

