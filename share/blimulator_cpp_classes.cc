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


int Net::get_value()
{
	return value;
}


void Net::set_value(int val)
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


void BitVector::set_value(uint64_t val)
{
	uint64_t mask;

	for (int i(0); i < width; i++) {
		mask = (uint64_t)1ULL << i;
		if ((val & mask) == 0) {
			nets[i]->set_value(0);
		} else {
			nets[i]->set_value(1);
		}
	}
}


void BitVector::set_value(int64_t val)
{
	uint64_t mask;

	for (int i(0); i < width; i++) {
		mask = (uint64_t)1ULL << i;
		if ((val & mask) == 0) {
			nets[i]->set_value(0);
		} else {
			nets[i]->set_value(1);
		}
	}
}


uint64_t BitVector::get_value(bool *valid)
{
	uint64_t res(0);
	int netVal;

	if (valid != NULL) {
		*valid = true;
	}

	for (int i(0); i < width; i++) {
		netVal = nets[i]->get_value();
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


int64_t BitVector::get_value_signed(bool *valid)
{
	int64_t res(0);
	unsigned int netVal;
	int i;

	if (valid != NULL) {
		*valid = true;
	}

	for (i = 0; i < width; i++) {
		netVal = nets[i]->get_value();
		if (netVal == 2) {
			if (valid != NULL) {
				*valid = false;
			}
			return 0;
		}
		res |= ((uint64_t)netVal << (uint64_t)i);
	}
	if (nets[width-1]->get_value() == 1) {
		for (i = width; i < 64; i++) {
			res |= (1UL << (uint64_t)i);
		}
	}


	return res;
}


int  BitVector::bit_width()
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
	output->set_value(initValue);
}


void Latch::clock()
{
	output->set_value(input->get_value());
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
		val = inputs[i]->get_value();
		if (val == 2) {
			output->set_value(2);
			return;
		}
		addr |= (val << i);
	}

	shift = addr & 0x1f;
	index = addr >> 5;

	output->set_value((singleOutputCover[index] >> shift) & 1);
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
		nets[i]->set_value(2);
	}

	for (i = 0; i < nbLatches; i++) {
		latches[i]->reset();
	}

	set_constants();
}


void Model::set_nets(Net **netArr)
{
	nets = netArr;
}


void Model::set_latches(Latch **latchArr)
{
	latches = latchArr;
}


void Model::set_gates(Gate **gateArr)
{
	gates = gateArr;
}


void Model::set_changes(bool *changeArr)
{
	changed = changeArr;
}

