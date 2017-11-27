#include <cmath>
#include "sqrt8_cpp_header.hh"

int main(void)
{
	uint64_t in, out, golden;
	int iterations = 0, nb_errors = 0;

	Sqrt8SimulationClass *dut = new Sqrt8SimulationClass();

	dut->reset();

	for (in = 0; in < 256; in++) {
		iterations++;

		dut->INPUT_VECTOR_radicand->setValue(in);
		dut->INPUT_NET_go->setValue(1);
		dut->cycle();
		dut->INPUT_NET_go->setValue(0);
		dut->cycle();

		while (dut->OUTPUT_NET_done->getValue() != 1) {
			dut->clock();
			dut->propagate();
		}

		out = dut->OUTPUT_VECTOR_squareRoot->getValue(NULL);
		golden = (int)sqrt(in);
		if (out != golden) {
			std::cerr << "sqrt(" << in << ") => " << out << " (should be " << golden << ")" << std::endl;
			nb_errors += 1;
		}
		else
			std::cout << "sqrt(" << in << ") = " << out << std::endl;
	}

	delete dut;

	if (nb_errors > 0) {
		std::cerr << "C++ simulation: FAILED: " << nb_errors << "/" << iterations << " errors (" << (float)nb_errors*100.0f/(float)iterations << std::endl;
		return EXIT_FAILURE;
	}

	std::cout << "C++ simulation: PASSED" << std::endl;

	return EXIT_SUCCESS;
}

