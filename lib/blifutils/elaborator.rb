##
# Copyright (C) 2017 Théotime bollengier <theotime.bollengier@gmail.com>
#
# This file is part of Blifutils.
#
# Blifutils is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Blifutils is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Blifutils. If not, see <http://www.gnu.org/licenses/>.


require 'blifutils/parser.rb'
require 'blifutils/ast.rb'
require 'blifutils/netlist.rb'


module BlifUtils

	module Elaborator

		def self.elaborate_netlist (ast, quiet: false, default_latch_type: nil, default_latch_clock: nil, default_latch_initial_value: nil)
			modelDeclarations = gather_model_declarations(ast)

			netlist = BlifUtils::Netlist.new
			models = ast.modelList.collect do |modelAst|
				puts "Elaborating model \"#{modelAst.name}\"..." unless quiet
				netlist.add_model(elaborate_model(modelAst, modelDeclarations, quiet: quiet, default_latch_type: default_latch_type, default_latch_clock: default_latch_clock, default_latch_initial_value: default_latch_initial_value))
			end

			return netlist
		end # BlifUtils::Elaborator::elaborate_netlist


		private


		class ModelDeclaration
			attr_reader :name
			attr_reader :inputs  #[String, ... ]
			attr_reader :outputs #[String, ... ]

			def initialize (name, inputs, outputs)
				@name = name
				@inputs = inputs
				@outputs = outputs
			end

			def to_s
				str  = "Model \"#{@name}\"\n"
				str += "  Inputs:  #{@inputs.join(', ')}\n"
				str += "  Outputs: #{@outputs.join(', ')}\n"
				return str
			end
		end # BlifUtils::Elaborator::ModelDeclaration


		def self.gather_model_declarations (ast)
			modelDeclarations = ast.modelList.collect do |modelAst|
				inputs = []
				modelAst.header.select{|headerElement| headerElement.class == BlifUtils::AST::ModelHeaderElementInputs}.each do |headerInput|
					headerInput.inputList.each do |inputStr|
						inputs << inputStr
					end
				end
				outputs = []
				modelAst.header.select{|headerElement| headerElement.class == BlifUtils::AST::ModelHeaderElementOutputs}.each do |headerOutput|
					headerOutput.outputList.each do |outputStr|
						outputs << outputStr
					end
				end
				BlifUtils::Elaborator::ModelDeclaration.new(modelAst.name, inputs, outputs)
			end

			# Check that each model is defined only once #
			(0 ... (modelDeclarations.length - 1)).each do |i|
				md1name = modelDeclarations[i].name
				((i+1) ... modelDeclarations.length).each do |j|
					md2name = modelDeclarations[j].name
					if md1name == md2name then
						abort "ERROR: Model \"#{md1name}\" is defined more than once"
					end
				end
			end

			return modelDeclarations
		end # BlifUtils::Elaborator::gather_model_declarations


		def self.elaborate_model (modelAst, modelDeclarations, quiet: false, default_latch_type: nil, default_latch_clock: nil, default_latch_initial_value: nil)
			name = modelAst.name
			inputs = []
			outputs = []
			components = []
			nets = []
			clocks = []

			# Create inputs #
			modelAst.header.select{|headerElement| headerElement.class == BlifUtils::AST::ModelHeaderElementInputs}.each do |headerInput|
				headerInput.inputList.each do |inputStr|
					if inputs.include?(inputStr) then
						abort "ERROR: In model \"#{name}\": input \"#{inputStr}\" is declared more than once"
					end
					inputs << BlifUtils::Netlist::IO.new(inputStr, inputStr)
				end
			end

			# Create outputs #
			modelAst.header.select{|headerElement| headerElement.class == BlifUtils::AST::ModelHeaderElementOutputs}.each do |headerOutput|
				headerOutput.outputList.each do |outputStr|
					if outputs.include?(outputStr) then
						abort "ERROR: In model \"#{name}\": output \"#{outputStr}\" is declared more than once"
					end
					outputs << BlifUtils::Netlist::IO.new(outputStr, outputStr)
				end
			end

			unless modelAst.commands.index{|commandAst| commandAst.class == BlifUtils::AST::BlackBox}.nil? then
				return BlifUtils::Netlist::Model.new(name, inputs, outputs, components, nets, clocks, true)
			end

			# Create components #
			modelAst.commands.each do |commandAst|
				if commandAst.class == BlifUtils::AST::LogicGate then
					components << BlifUtils::Netlist::LogicGate.new(commandAst.inputs, commandAst.output, commandAst.single_output_cover_list)
				elsif commandAst.class == BlifUtils::AST::GenericLatch then
					components << BlifUtils::Netlist::Latch.new(commandAst.input, commandAst.output, commandAst.initValue, commandAst.ctrlType, commandAst.ctrlSig)
				elsif commandAst.class == BlifUtils::AST::ModelReference then
					modelDeclarationIndex = modelDeclarations.index{|md| md.name == commandAst.modelName}
					if modelDeclarationIndex.nil? then
						abort "ERROR: In model \"#{name}\": model \"#{commandAst.modelName}\" is referenced but is not defined in the parsed blif files"
					end
					modelDeclaration = modelDeclarations[modelDeclarationIndex]
					inputFormalAcutalList = []
					outputFormalAcutalList = []
					commandAst.formalAcutalList.each do |form_act| 
						newIO = BlifUtils::Netlist::IO.new(form_act[0], form_act[1])
						if modelDeclaration.inputs.include?(newIO.name) then
							inputFormalAcutalList << newIO
						elsif modelDeclaration.outputs.include?(newIO.name) then
							outputFormalAcutalList << newIO
						else
							abort "ERROR: In model \"#{name}\": model \"#{commandAst.modelName}\" is referenced with formal \"#{newIO.name}\" which is neither an input nor an output of this referenced model"
						end
					end
					components << BlifUtils::Netlist::SubCircuit.new(commandAst.modelName, inputFormalAcutalList, outputFormalAcutalList)
				end
			end

			if default_latch_type then
				components.each do |c|
					next unless c.isLatch? and c.ctrlType.nil?
					c.set_type(default_latch_type)
				end
			end

			if default_latch_clock then
				components.each do |c|
					next unless c.isLatch? and c.ctrlSig.nil?
					c.set_clock(default_latch_clock)
				end
			end

			if default_latch_initial_value then
				components.each do |c|
					next unless c.isLatch? and c.initValue.nil?
					c.set_initial_value(default_latch_initial_value)
				end
			end


			# Create all nets from their drivers #
			netnames = {}
			inputs.each do |iIO|
				newNet = BlifUtils::Netlist::Net.new(iIO.net, :input, [], true, false)
				netnames[newNet.name] = newNet
				nets << newNet
				iIO.net = newNet
			end
			components.reject{|comp| comp.isSubcircuit?}.each do |component|
				newNet = BlifUtils::Netlist::Net.new(component.output, component, [], false, false)
				abort "ERROR: In model \"#{name}\": net \"#{newNet.name}\" has more than one driver" if netnames[newNet.name]
				netnames[newNet.name] = newNet
				nets << newNet
				component.output = newNet
			end
			components.select{|comp| comp.isSubcircuit?}.each do |subcircuit|
				subcircuit.outputFormalAcutalList.each do |outIO|
					newNet = BlifUtils::Netlist::Net.new(outIO.net, subcircuit, [], false, false)
					abort "ERROR: In model \"#{name}\": net \"#{newNet.name}\" has more than one driver" if netnames[newNet.name]
					netnames[newNet.name] = newNet
					nets << newNet
					outIO.net = newNet
				end
			end

			# Update nets fanouts #
			outputs.each_with_index do |oIO, i|
				theNet = netnames[oIO.name]
				abort "ERROR: In model \"#{name}\": output \"#{oIO.name}\" has no driver" if theNet.nil?
				theNet.fanouts << BlifUtils::Netlist::Fanout.new(:output, i)
				theNet.isOutput = true
				oIO.net = theNet
			end
			components.select{|comp| comp.isLatch?}.each do |latch|
				theNet = netnames[latch.input]
				abort "ERROR: In model \"#{name}\": input \"#{latch.input}\" from latch \"#{latch.output.name}\" has no driver" if theNet.nil?
				theNet.fanouts << BlifUtils::Netlist::Fanout.new(latch, 0)
				latch.input = theNet
			end
			components.select{|comp| comp.isGate?}.each do |gate|
				gate.inputs.each_with_index do |gin, i|
					theNet = netnames[gin]
					abort "ERROR: In model \"#{name}\": input \"#{gin}\" from gate \"#{gate.output.name}\" has no driver" if theNet.nil?
					theNet.fanouts << BlifUtils::Netlist::Fanout.new(gate, i)
					gate.inputs[i] = theNet
				end
			end
			components.select{|comp| comp.isSubcircuit?}.each do |subcircuit|
				subcircuit.inputFormalAcutalList.each_with_index do |iIO, i|
					theNet = netnames[iIO.net]
					abort "ERROR: In model \"#{name}\": input \"#{iIO}\" (formal \"#{iIO.name}\" from reference model \"#{subcircuit.modelName}\" has no driver" if theNet.nil?
					theNet.fanouts << BlifUtils::Netlist::Fanout.new(subcircuit, i)
					iIO.net = theNet
				end
			end

			clocks = components.select{|comp| comp.isLatch?}.collect{|latch| latch.ctrlSig}.reject{|el| el.nil?}.uniq

			# Check that each net has at least one fanout #
			unless quiet then
				nets.each do |net|
					if net.fanouts.empty? and not(clocks.include?(net.name)) then
						STDERR.puts "WARNING: In model \"#{name}\": net \"#{net.name}\" has no fanouts"
					end
				end
			end

			return BlifUtils::Netlist::Model.new(name, inputs, outputs, components, nets, clocks)
		end # BlifUtils::Elaborator::elaborate_model

	end # BlifUtils::Elaborator


	def self.read(fileName, quiet: false, default_latch_type: nil, default_latch_clock: nil, default_latch_initial_value: nil)
		ast = BlifUtils::Parser.parse(fileName, quiet: quiet)
		netlist = BlifUtils::Elaborator.elaborate_netlist(ast, quiet: quiet, default_latch_type: nil, default_latch_clock: nil, default_latch_initial_value: nil)
		return netlist
	end # BlifUtils::read

end # BlifUtils



if __FILE__ == $0
	if ARGV.length == 0
		puts "You must provide the file to process as argument!"
		exit
	end

	ast = BlifUtils::Parser.parse(ARGV[0])

	netlist = BlifUtils::Elaborator.elaborate_netlist(ast)
	puts netlist.analyze
end

