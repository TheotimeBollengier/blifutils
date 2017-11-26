/*
 * Copyright (C) 2017 Théotime bollengier <theotime.bollengier@gmail.com>
 *
 * This file is part of Blifutils.
 *
 * Blifutils is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Blifutils is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Blifutils. If not, see <http://www.gnu.org/licenses/>.
 *
 */


#include <inttypes.h>
#include <iostream>
#include <cstdlib>


class Net
{
	private:

		int   value;    // 0, 1 or 2 for unknown
		int   nbFanoutComponentIndex;
		int  *fanoutComponentIndex;
		bool *gateChanged;

	public:

		Net(int *fanoutIndexes, int fanoutIndexesLength, bool *gateChangedArray);
		~Net();

		int  getValue();
		void setValue(int val);
};


class BitVector
{
	/* For now we are doing with uint64_t, will see later for more than 64 bits */

	private:

		int   width;
		Net **nets;

	public:

		BitVector(Net **netArray, int bitwidth);
		~BitVector();

		void setValue(int64_t val);
		void setValue(uint64_t val);

		uint64_t getValue(bool *valid);
		int64_t  getValueSigned(bool *valid);

		int  bitWidth();
};


class Latch
{
	private:

		Net *input;
		Net *output;
		int initValue;
		
	public:

		Latch(Net *inputNet, Net *outputNet, int initVal);

		void reset();
		void clock();
};


class Gate
{
	private:

		int       nbInputs;
		Net      **inputs;
		Net      *output;
		uint32_t *singleOutputCover;

	public:

		Gate(Net **inputNets, int nbinputs, Net *outputNet, uint32_t *singleoutputcover);
		~Gate();

		void propagate();
};


class Model
{
	private:

		unsigned int nbNets;
		unsigned int nbLatches;
		unsigned int nbGates;

		Net   **nets;
		Latch **latches;
		Gate  **gates;
		bool   *changed;

	public:

		Model(unsigned int nbNet, unsigned int nbLatche, unsigned int nbGate);
		virtual ~Model();

		void propagate(); 
		void clock(); 
		void cycle();
		void reset();

	protected:

		virtual void setConstants() = 0;
		void setNets(Net **netArr);
		void setLatches(Latch **latchArr);
		void setGates(Gate **gateArr);
		void setChanges(bool *changeArr);
};


/******************************************************************************/


Net::Net(int *fanoutIndexes, int fanoutIndexesLength, bool *gateChangedArray) :
	value(2),
	nbFanoutComponentIndex(fanoutIndexesLength),
	fanoutComponentIndex(fanoutIndexes),
	gateChanged(gateChangedArray)
{
}


Net::~Net()
{
	if (fanoutComponentIndex) {
		delete fanoutComponentIndex;
	}
}


int Net::getValue()
{
	return value;
}


void Net::setValue(int val)
{
	if (val != value) {
		for (int i(0); i < nbFanoutComponentIndex; i++) {
			gateChanged[fanoutComponentIndex[i]] = true;
		}
	}
	value = val & 3;
}


/******************************************************************************/


BitVector::BitVector(Net **netArray, int bitwidth) :
	width(bitwidth),
	nets(netArray)
{
	if (bitwidth > 64) {
		std::cerr << "ERROR: For now bit vectors are limited to 64 bits, sorry" << std::endl;
		exit(EXIT_FAILURE);
	}
}


BitVector::~BitVector()
{
	if (nets) {
		delete nets;
	}
}


void BitVector::setValue(uint64_t val)
{
	uint64_t mask;

	for (int i(0); i < width; i++) {
		mask = (uint64_t)1ULL << i;
		if ((val & mask) == 0) {
			nets[i]->setValue(0);
		} else {
			nets[i]->setValue(1);
		}
	}
}


void BitVector::setValue(int64_t val)
{
	uint64_t mask;

	for (int i(0); i < width; i++) {
		mask = (uint64_t)1ULL << i;
		if ((val & mask) == 0) {
			nets[i]->setValue(0);
		} else {
			nets[i]->setValue(1);
		}
	}
}


uint64_t BitVector::getValue(bool *valid)
{
	uint64_t res(0);
	int netVal;

	if (valid != NULL) {
		*valid = true;
	}

	for (int i(0); i < width; i++) {
		netVal = nets[i]->getValue();
		if (netVal == 2) {
			if (valid != NULL) {
				*valid = false;
			}
			return 0;
		}
		res |= (netVal << i);
	}

	return res;
}


int64_t BitVector::getValueSigned(bool *valid)
{
	int64_t res(0);
	unsigned int netVal;
	int i;

	if (valid != NULL) {
		*valid = true;
	}

	for (i = 0; i < width; i++) {
		netVal = nets[i]->getValue();
		if (netVal == 2) {
			if (valid != NULL) {
				*valid = false;
			}
			return 0;
		}
		res |= ((uint64_t)netVal << (uint64_t)i);
	}
	if (nets[width-1]->getValue() == 1) {
		for (i = width; i < 64; i++) {
			res |= (1UL << (uint64_t)i);
		}
	}


	return res;
}


int  BitVector::bitWidth()
{
	return width;
}


/******************************************************************************/


Latch::Latch(Net *inputNet, Net *outputNet, int initVal) :
	input(inputNet),
	output(outputNet),
	initValue(initVal)
{
	if (initValue != 0 && initValue != 1) {
		initValue = 2;
	}
}


void Latch::reset()
{
	output->setValue(initValue);
}


void Latch::clock()
{
	output->setValue(input->getValue());
}


/******************************************************************************/


Gate::Gate(Net **inputNets, int nbinputs, Net *outputNet, uint32_t *singleoutputcover) :
	nbInputs(nbinputs),
	inputs(inputNets),
	output(outputNet),
	singleOutputCover(singleoutputcover)
{
}


Gate::~Gate()
{
	if (singleOutputCover) {
		delete singleOutputCover;
	}

	if (inputs) {
		delete inputs;
	}
}


void Gate::propagate()
{
	uint32_t addr(0);
	uint32_t index(0);
	uint32_t shift(0);
	int val;

	for (int i(0); i < nbInputs; i++) {
		val = inputs[i]->getValue();
		if (val == 2) {
			output->setValue(2);
			return;
		}
		addr |= (val << i);
	}

	shift = addr & 0x1f;
	index = addr >> 5;

	output->setValue((singleOutputCover[index] >> shift) & 1);
}


/******************************************************************************/


Model::Model(unsigned int nbNet, unsigned int nbLatche, unsigned int nbGate) :
	nbNets(nbNet),
	nbLatches(nbLatche),
	nbGates(nbGate),
	nets(NULL),
	latches(NULL),
	gates(NULL),
	changed(NULL)
{
}


Model::~Model()
{
}


void Model::propagate()
{
	for (unsigned int i(0); i < nbGates; i++) {
		if (changed[i]) {
			gates[i]->propagate();
			changed[i] = false;
		}
	}
}


void Model::clock()
{
	for (unsigned int i(0); i < nbLatches; i++) {
		latches[i]->clock();
	}
}


void Model::cycle()
{
	propagate();
	clock();
	propagate();
}


void Model::reset()
{
	unsigned int i;

	for (i = 0; i < nbNets; i++) {
		nets[i]->setValue(2);
	}

	for (i = 0; i < nbLatches; i++) {
		latches[i]->reset();
	}

	setConstants();
}


void Model::setNets(Net **netArr)
{
	nets = netArr;
}


void Model::setLatches(Latch **latchArr)
{
	latches = latchArr;
}


void Model::setGates(Gate **gateArr)
{
	gates = gateArr;
}


void Model::setChanges(bool *changeArr)
{
	changed = changeArr;
}

