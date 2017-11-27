Gem::Specification.new do |s|
	s.name        = 'blifutils'
	s.version     = '0.0.1'
	s.date        = '2017-11-26'
	s.summary     = 'BlifUtils is a library to handle BLIF netlists in Ruby.'
	s.description = "BlifUtils is a library to handle BLIF logic netlists in Ruby. It can read and write files in the BLIF format, elaborate internal representations of the netlists, analyze it, flattent modules, write the modules as VHDL entities, and generate C++ code for fast simulation of the netlists."
	s.authors     = 'Théotime Bollengier'
	s.email       = 'theotime.bollengier@gmail.com'
	s.homepage    = 'http://github.com/TheotimeBollengier/blifutils'
	s.license     = 'GPL-3.0'
	s.executables = ['blifutils']
	s.files       = ['README.md',
	                 'LICENSE',
	                 'bin/blifutils',
	                 'share/blimulator_cpp_classes.cc',
	                 'share/blimulator_cpp_classes.hh',
	                 'lib/blifutils.rb',
	                 'lib/blifutils/ast.rb',
	                 'lib/blifutils/blif_to_vhdl.rb',
	                 'lib/blifutils/elaborator.rb',
	                 'lib/blifutils/layering.rb',
	                 'lib/blifutils/level_analyzer.rb',
	                 'lib/blifutils/lexer.rb',
	                 'lib/blifutils/netlist.rb',
	                 'lib/blifutils/parser.rb',
	                 'lib/blifutils/simulator_generator.rb',
					 'test/sqrt8.blif',
					 'test/sqrt8_PC.blif',
					 'test/sqrt8_PC_counter.blif',
					 'test/sqrt8_PC_done.blif',
					 'test/sqrt8_PC_state.blif',
					 'test/sqrt8.piccolo',
					 'test/sqrt8_PO.blif',
					 'test/sqrt8_PO_output.blif',
					 'test/sqrt8_PO_sqrtr.blif',
					 'test/sqrt8_PO_work.blif',
					 'test/testbench_sqrt8.cc',
					 'test/test_blifutils.rb',
					 'examples/zpu/simulate_zpu.rb',
					 'examples/zpu/testbench_zpu.cc',
					 'examples/zpu/zpu_helloworld.bin',
					 'examples/zpu/zpu_mem16.blif',
					 'examples/zpu/zpu_mem16.piccolo'
	                ]
	s.add_runtime_dependency 'rltk', '~> 3.0', '>= 3.0.1'
end
