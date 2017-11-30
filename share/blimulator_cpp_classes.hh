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

	int   value; // 0, 1 or 2 for unknown
	int   nbFanoutComponentIndex;
	int  *fanoutComponentIndex;
	bool *gateChanged;

public:

	Net(int *fanoutIndexes, int fanoutIndexesLength, bool *gateChangedArray);
	~Net();

	int  get_value();
	void set_value(int val);
};


class BitVector
{
	/* For now we are doing with uint64_t to set BitVector values, 
	 * will see later for more than 64 bits.
	 */

private:

	int   width;
	Net **nets;

public:

	BitVector(Net **netArray, int bitwidth);
	~BitVector();

	void set_value(int64_t val);
	void set_value(uint64_t val);

	uint64_t get_value(bool *valid = NULL);
	int64_t  get_value_signed(bool *valid = NULL);

	int  bit_width();
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

	int        nbInputs;
	Net      **inputs;
	Net       *output;
	uint32_t  *singleOutputCover;

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

	virtual void set_constants() = 0;
	void         set_nets(Net **netArr);
	void         set_latches(Latch **latchArr);
	void         set_gates(Gate **gateArr);
	void         set_changes(bool *changeArr);
};

