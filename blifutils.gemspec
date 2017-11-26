Gem::Specification.new do |s|
	s.name        = 'blifutils'
	s.version     = '0.0.1'
	s.date        = '2017-11-26'
	s.summary     = 'BlifUtils is a library to handle BLIF netlists in Ruby.'
	s.description = "BlifUtils is a library to handle BLIF logic netlists in Ruby. It can read and write files in the BLIF format, elaborate internal representations of the netlists, analyze it, flattent modules, write the modules as VHDL entities, and generate C++ code for fast simulation of the netlists."
	s.authors     = 'Théotime Bollengier'
	s.email       = 'theotime.bollengier@gmail.com'
	s.homepage    = 'http://github.com/TheotimeBollengier/blifutils'
	s.license     = 'GPLv3'
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
	                 'lib/blifutils/simulator_generator.rb'
	                ]
	s.add_runtime_dependency 'rltk'
end
