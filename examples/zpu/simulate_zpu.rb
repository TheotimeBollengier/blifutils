#!/usr/bin/env ruby

require_relative '../../lib/blifutils'

netlist = BlifUtils::read('zpu_mem16.blif')

puts '-'*60
puts netlist.analyze
puts '-'*60

netlist.create_simulation_file_for_model

puts '-- Compiling testbench '.ljust(60, '-')
testbench_exec = 'zpu_simulation'
cmd = "g++ -W -Wall -I. -o #{testbench_exec} testbench_zpu.cc zpu_mem16_cpp_sim.o"
puts "Executing: #{cmd}"
abort unless system cmd
puts "You can now execute the testbench with \"./#{testbench_exec} <zpu_compiled_program>\""

puts '-- Executing simulation '.ljust(60, '-')
cmd = "./#{testbench_exec} zpu_helloworld.bin"
puts "Executing: #{cmd}"
abort unless system cmd
