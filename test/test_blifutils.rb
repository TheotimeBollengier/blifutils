#!/usr/bin/env ruby

require_relative '../lib/blifutils.rb'

golden_model_names = [
	"sqrt8", 
	"sqrt8_PO", 
	"sqrt8_PO_output", 
	"sqrt8_PO_sqrtr", 
	"sqrt8_PO_work", 
	"sqrt8_PC", 
	"sqrt8_PC_done", 
	"sqrt8_PC_state", 
	"sqrt8_PC_counter"
]

golden_model_analyze = {
	name:      "sqrt8", 
	nb_inputs:      10, 
	nb_outputs:      5, 
	is_blackbox: false, 
	nb_nets:       115, 
	nb_edges:      248, 
	nb_nodes:      106, 
	nb_latches:     29, 
	nb_gates:       77, 
	nb_subckt:       0, 
	gates: {
		gates_per_nb_inputs: {
			4 => 13, 
			1 => 19, 
			2 => 30, 
			5 =>  7, 
			6 =>  8
		}, 
		nb_buffers:   5, 
		nb_constants: 0
	}
}

golden_level = 16


input_file_name = File.join(File.dirname(File.expand_path(__FILE__)), 'sqrt8.blif')

netlist = BlifUtils::read(input_file_name)

model_names = netlist.models.collect{|model| model.name}
abort "FAIL: Retreived models have different names" if model_names != golden_model_names

sqrt8_flattened = netlist.flatten('sqrt8')

analyze = sqrt8_flattened.analyze_to_hash
analyze.each{|k, v| puts "#{k} -> #{v}"}
abort "FAIL: Flattened model is different from the golden model" if analyze != golden_model_analyze

level = sqrt8_flattened.level
puts "Logic level: #{level}"
abort "FAIL: logic level different from golden level" if level != golden_level

netlist.clear.add_model(sqrt8_flattened).create_simulation_file_for_model('sqrt8')

testbench_dir  = '.'
testbench_src  = 'testbench_sqrt8.cc'
testbench_obj  = 'sqrt8_cpp_sim.o'
testbench_exec = 'sqrt8_cpp_sim'

cmd = "g++ -W -Wall -I#{testbench_dir} -o #{testbench_exec} #{testbench_src} #{testbench_obj}"
puts "Executing: #{cmd}"
abort unless system cmd

puts "Executing: #{testbench_exec}"
abort unless system "./#{testbench_exec}"

puts
puts 'TEST PASSED'

