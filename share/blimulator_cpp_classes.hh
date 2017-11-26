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

