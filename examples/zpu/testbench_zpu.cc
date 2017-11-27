#include "zpu_mem16_cpp_header.hh"
#include <cstdlib>
#include <cstdio>
#include <cmath>
#include <ctime>
#include <unistd.h>


int main(int argc, char *argv[])
{
	uint32_t mem[8192];
	uint32_t addr(0);
	uint32_t word;
	int byte;
	FILE *inFile(NULL);
	unsigned int cclock(0);
	ZpuMem16SimulationClass *dut;
    clock_t startTime, stopTime;
	bool valid;

	if (argc != 2) {
		fprintf(stderr, "usage: %s <bin_file>\n", argv[0]);
		return EXIT_FAILURE;
	}

	if ((inFile = fopen(argv[1], "r")) == NULL) {
		fprintf(stderr, "Cannot open file \"%s\"\n", argv[1]);
		return EXIT_FAILURE;
	}

	/* Load simulation memory in big-endian */
	for (addr = 0; addr < (sizeof(mem) / 4); addr++) {
		word = 0;

		byte = fgetc(inFile);
		if (byte == EOF) {
			break;
		}
		word |= byte << 24;
		byte = fgetc(inFile);
		if (byte == EOF) {
			break;
		}
		word |= byte << 16;
		byte = fgetc(inFile);
		if (byte == EOF) {
			break;
		}
		word |= byte << 8;
		byte = fgetc(inFile);
		if (byte == EOF) {
			break;
		}
		word |= byte;
		mem[addr] = word;
	}

	fclose(inFile);

	printf("Read %u bytes from file '%s' (memory filled %.1f%%)\n",
			(addr << 2), argv[1], (float)addr * 100.0f / (float)(sizeof(mem) / 4.0f));

	for (; addr < (sizeof(mem) / 4); addr++) {
		mem[addr] = 0;
	}

	dut = new ZpuMem16SimulationClass();

	printf("Starting simulation\n");

	startTime = clock();

	dut->reset();
	dut->INPUT_VECTOR_DAT_I->setValue(0UL);
	dut->INPUT_VECTOR_ACK_I->setValue(0UL);
	dut->propagate();

	/* Simulate a wishbone bus */
	while (dut->OUTPUT_NET_BREAKPOINT->getValue() != 1) {
		if (dut->OUTPUT_NET_CYC_O->getValue() == 1) {
			addr = dut->OUTPUT_VECTOR_ADR_O->getValue(&valid);
			if (valid != true) {
				std::cerr << "\033[1;31mADR_O not valid (" << cclock << ")\033[0m" << std::endl;
				exit(EXIT_FAILURE);
			}
			if (dut->OUTPUT_NET_WE_O->getValue() == 1) {
				if (addr >= (sizeof(mem) / 4)) {
					uint64_t car = dut->OUTPUT_VECTOR_DAT_O->getValue(&valid);
					if (valid != true) {
						std::cerr << "\033[1;31mDAT_O not valid (" << cclock << ")\033[0m" << std::endl;
						exit(EXIT_FAILURE);
					}
					write(1, &car, 1);
				} else {
					mem[addr] = (uint32_t)dut->OUTPUT_VECTOR_DAT_O->getValue(&valid);
					if (valid != true) {
						std::cerr << "\033[1;31mDAT_O not valid (" << cclock << ")\033[0m" << std::endl;
						exit(EXIT_FAILURE);
					}
				}
			} else {
				dut->INPUT_VECTOR_DAT_I->setValue((uint64_t)mem[addr]);
			}
			dut->INPUT_NET_ACK_I->setValue(1);
			dut->propagate();
			dut->clock();
			cclock++;
			dut->INPUT_NET_ACK_I->setValue(0);
			dut->propagate();
		} else {
			dut->clock();
			cclock++;
			dut->propagate();
		}
	}

	stopTime = clock();

	printf("Simulation ended\n");
	float execTime = (float)(stopTime - startTime)/(float)(CLOCKS_PER_SEC);
	printf("%u clock cycles in %.3f s\n", cclock, execTime);
	printf("Simulation average clock speed: %u Hz\n", (unsigned int)((float)cclock / execTime));


	delete dut;

	return EXIT_SUCCESS;
}

