
BlifUtils
=========

BlifUtils is a library to handle BLIF netlists in Ruby. 
The Berkeley Logic Interchange Format (BLIF) allows to describe logic-level 
hierarchical circuits in textual form. Its specification can be found 
[here](https://www.ece.cmu.edu/~ee760/760docs/blif.pdf). The BLIF format is 
used by programs such as [ABC](http://people.eecs.berkeley.edu/~alanmi/abc/) 
(logic synthesis) or [VPR](http://www.eecg.toronto.edu/~vaughn/papers/fpl97.pdf) 
(placement and routing). 

BlifUtils can read and write BLIF files, 
elaborate internal representations of the netlists, analyze it, flattent modules, 
write the modules as VHDL entities, and generate C++ code for fast 
netlist simulation.


Installation
------------

To install BlifUtils from the git repository:

```lang-none
$ git clone https://github.com/TheotimeBollengier/blifutils
$ cd blifutils
$ gem build blifutils.gemspec
$ gem install blifutils.<version>.gem
```

Alternatively, the blifutils gem is also hosted on RubyGems 
([https://rubygems.org/gems/blifutils](https://rubygems.org/gems/blifutils)).
So you can simply type:

```lang-none
$ gem install blifutils
```

BlifUtils uses the [RLTK](https://rubygems.org/gems/rltk) gem
([https://github.com/chriswailes/RLTK](https://github.com/chriswailes/RLTK)).


Example
-------

```ruby
require 'blifutils'

## Parse input file and sub-referenced files ##
netlist = BlifUtils::read('sqrt8.blif')

netlist.models.collect { |model| model.name }
#=> ["sqrt8",
#    "sqrt8_PO",
#    "sqrt8_PO_output",
#    "sqrt8_PO_sqrtr",
#    "sqrt8_PO_work",
#    "sqrt8_PC",
#    "sqrt8_PC_done",
#    "sqrt8_PC_state",
#    "sqrt8_PC_counter"]

puts netlist.get_model_by_name('sqrt8_PC').analyze
#=> "+----------------------------------------+
#    |       Model "sqrt8_PC" analysis        |
#    +----------------------------------------+
#    Model "sqrt8_PC"
#      Inputs: 2
#      Outputs: 3
#      Nets: 7
#      Edges: 13
#      Nodes: 3
#        Latches: 0
#        Logic gates: 0
#        Sub circuits: 3
#      Sub circuits repartition:
#        sqrt8_PC_done: 1
#        sqrt8_PC_state: 1
#        sqrt8_PC_counter: 1"

sqrt8pc_flattened_model = netlist.flatten('sqrt8_PC')

sqrt8pc_flattened_model.analyze
#=> "+----------------------------------------+
#    |       Model "sqrt8_PC" analysis        |
#    +----------------------------------------+
#    Model "sqrt8_PC"
#      Inputs: 2
#      Outputs: 3
#      Nets: 21
#      Edges: 38
#      Nodes: 19
#        Latches: 5
#        Logic gates: 14
#        Sub circuits: 0
#      Gates repartition:
#         1 input:     7  50.0%
#         2 inputs:    3  21.4%
#         4 inputs:    3  21.4%
#         5 inputs:    1   7.1%
#        Buffers:   3"

## Analyze the logic level of the module
## that is to say the maximum number of logic functions between two latches or IOs.
sqrt8pc_flattened_model.level #=> 4

sqrt8pc_flattened_model.to_blif
#=> ".model sqrt8_PC
#    .inputs _clk_ go[0]
#    .outputs done[0] state[1] state[0]
#    .latch n1 n0 re _clk_ 0
#    .latch n6 n2 re _clk_ 0
#    .latch n7 n3 re _clk_ 0
#    .latch nD nA re _clk_ 0
#    .latch nE nB re _clk_ 0
#    .names n2 n3 n1
#    11 1
#    .names n8 n9 n4
#    1- 1
#    -1 1
#    .names n4 n5
#    0 1
#    .names go[0] n2 n3 n2 n6
#    10-- 1
#    -01- 1
#    0001 1
#    .names go[0] n2 n3 n5 n3 n7
#    -10-- 1
#    -011- 1
#    000-1 1
#    .names nA n8
#    0 1
#    .names nB n9
#    0 1
#    .names nB nA nC
#    10 1
#    01 1
#    .names n2 n3 nA nF nD
#    1-1- 1
#    01-1 1
#    .names n2 n3 nB nC nE
#    1-1- 1
#    01-1 1
#    .names nA nF
#    0 1
#    .names n0 done[0]
#    1 1
#    .names n3 state[1]
#    1 1
#    .names n2 state[0]
#    1 1
#    .end"

sqrt8pc_flattened_model.to_vhdl
#=> "library IEEE;
#    use IEEE.STD_LOGIC_1164.ALL;
#    
#    
#    entity SQRT8_PC is
#    	port ( clk_in      : in  std_ulogic;
#    	       go_0_in     : in  std_ulogic;
#    	       done_0_out  : out std_ulogic;
#    	       state_1_out : out std_ulogic;
#    	       state_0_out : out std_ulogic);
#    end SQRT8_PC;
#    
#    
#    architecture blif of SQRT8_PC is
#    
#    	signal clk      : std_ulogic;
#    	signal go_0     : std_ulogic;
#    	signal n0       : std_ulogic := '0';
#    	signal n1       : std_ulogic;
#    	signal n2       : std_ulogic := '0';
#    	signal n3       : std_ulogic := '0';
#    	signal n4       : std_ulogic;
#    	signal n5       : std_ulogic;
#    	signal n6       : std_ulogic;
#    	signal n7       : std_ulogic;
#    	signal n8       : std_ulogic;
#    	signal n9       : std_ulogic;
#    	signal nA       : std_ulogic := '0';
#    	signal nB       : std_ulogic := '0';
#    	signal nC       : std_ulogic;
#    	signal nD       : std_ulogic;
#    	signal nE       : std_ulogic;
#    	signal nF       : std_ulogic;
#    	signal done_0   : std_ulogic;
#    	signal state_1  : std_ulogic;
#    	signal state_0  : std_ulogic;
#    
#    begin
#    
#    	clk <= clk_in;
#    	go_0 <= go_0_in;
#    
#    	done_0_out <= done_0;
#    	state_1_out <= state_1;
#    	state_0_out <= state_0;
#    
#    
#    	process(clk)
#    	begin
#    		if rising_edge(clk) then
#    			n0 <= n1;
#    			n2 <= n6;
#    			n3 <= n7;
#    			nA <= nD;
#    			nB <= nE;
#    		end if;
#    	end process;
#    
#    	n1 <= (n2 and n3);
#    	n4 <= (n8) or
#    	      (n9);
#    	n5 <= (not(n4));
#    	n6 <= (go_0 and not(n2)) or
#    	      (not(n2) and n3) or
#    	      (not(go_0) and not(n2) and not(n3) and n2);
#    	n7 <= (n2 and not(n3)) or
#    	      (not(n2) and n3 and n5) or
#    	      (not(go_0) and not(n2) and not(n3) and n3);
#    	n8 <= (not(nA));
#    	n9 <= (not(nB));
#    	nC <= (nB and not(nA)) or
#    	      (not(nB) and nA);
#    	nD <= (n2 and nA) or
#    	      (not(n2) and n3 and nF);
#    	nE <= (n2 and nB) or
#    	      (not(n2) and n3 and nC);
#    	nF <= (not(nA));
#    	done_0 <= (n0);
#    	state_1 <= (n3);
#    	state_0 <= (n2);
#    
#    end blif;

netlist.create_simulation_file_for_model('sqrt8')
# Creates files sqrt8_cpp_header.hh  sqrt8_cpp_sim.cc
# and compiles to sqrt8_cpp_sim.o 
```

You can then write a C++ testbench:

```C++
#include <cmath>
#include "sqrt8_cpp_header.hh"

int main(void)
{
	uint64_t in, out, golden;

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
			dut->propagate();
			dut->clock();
			dut->propagate();
			// equivalent to 'dut->cycle()'
		}

		out = dut->OUTPUT_VECTOR_squareRoot->getValue(NULL);
		golden = (int)sqrt(in);
		if (out != golden) {
			std::cerr << "sqrt(" << in << ") => " << out << " (should be " << golden << ")" << std::endl;
		}
	}

	delete dut;

	return 0;
}
```

Compile and execute this testbench:

```lang-none
$ g++ -W -Wall -I. -o simu testbench.cc sqrt8_cpp_sim.o
$ ./simu
```

---

The `examples/zpu/` directory contains the necessary files to simulate
a ZPU ZPU processor [https://github.com/zylin/zpu](https://github.com/zylin/zpu)
executing a hello-world.

```lang-none
$ cd examples/zpu
$ ruby simulate_zpu.rb

Parsing file "zpu_mem16.blif"...
Elaborating model "zpu_mem16"...
WARNING: In model "zpu_mem16": net "_clk_" has no fanouts
------------------------------------------------------------
Model collection contains 1 models
+----------------------------------------+
|       Model "zpu_mem16" analysis       |
+----------------------------------------+
Model "zpu_mem16"
  Inputs: 34
  Outputs: 50
  Nets: 1006
  Edges: 4039
  Nodes: 972
    Latches: 156
    Logic gates: 816
    Sub circuits: 0
  Gates repartition:
     1 input:    51   6.3%
     2 inputs:   33   4.0%
     3 inputs:   95  11.6%
     4 inputs:  108  13.2%
     5 inputs:  175  21.4%
     6 inputs:  354  43.4%
    Buffers:   51
------------------------------------------------------------
Generating graph from model components...
Extracting connected subgraphs... 87 subgraphs found
Checking that there are no cycles in subgraphs... Ok
Layering subgraphs...
Maximum number of layers: 33
Writing static schedule for component simulation...
Written C++ simulation model in file "zpu_mem16_cpp_sim.cc"
Compiling model...
g++ -c -W -Wall -O3 -std=c++11 zpu_mem16_cpp_sim.cc -o zpu_mem16_cpp_sim.o
Written C++ model simulation header in file "zpu_mem16_cpp_header.hh"
Now you can write your testbench in a C++ file as 'testbench.cc' including '#include "zpu_mem16_cpp_header.hh"', then run:
g++ -W -Wall -O3 zpu_mem16_cpp_sim.o testbench.cc
-- Compiling testbench -------------------------------------
Executing: g++ -W -Wall -I. -o zpu_simulation testbench_zpu.cc zpu_mem16_cpp_sim.o
You can now execute the testbench with "./zpu_simulation <zpu_compiled_program>"
-- Executing simulation ------------------------------------
Executing: ./zpu_simulation zpu_helloworld.bin
Read 3284 bytes from file 'zpu_helloworld.bin' (memory filled 10.0%)
Starting simulation
Hello, world!
What you see is a processor simulated at a logic netlist level, executing a helloworld.
Simulation ended
80877 clock cycles in 1.271 s
Simulation average clock speed: 63637 Hzxecutable
```


Executable
----------

To use BlifUtils directly from a terminal or a Makefile,
this gem also include the `blifutils` executable script, which uses command line arguments.

```lang-none
$ blifutils --help
Usage: blifutils [options] -i file1 file2 ...
    -i, --input FILES                Input blif files
    -o, --output [FILE]              Output blif to FILE
    -s, --simulation                 Create C++ simulation files
    -v, --vhdl                       Create a vhdl file
    -f, --flatten                    Flatten the model hierarchy in a single model
    -m, --model NAME                 Name of the model to process
    -p, --print-models               Print model names
    -a, --analyze [level]            Print analysis, with optional level analysis (level)
    -A, --analyze_with_graphviz      Print analysis, with level analysis, wirting graphvis files
    -q, --quiet                      Don't print messages
    -h, --help                       Display this help
```

