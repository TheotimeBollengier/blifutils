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


require_relative 'netlist.rb'
require_relative 'layering.rb'


module BlifUtils

	class Netlist

		class LogicGate

			def get_simulation_table
				table = get_LookUpTable()
				tableLength = table.length

				uint32table = []
				pos = 0
				begin
					tableCont = 0
					(0 ... 32).each do |j|
						tagada = pos + j
						break if tagada >= tableLength
						if table[tagada] == 1 then
							tableCont |= (1 << j)
						end
					end
					pos += 32
					uint32table << tableCont
				end while pos < tableLength

				return uint32table.collect{|num| num.to_s}.join(', ')
			end

		end # BlifUtils::Netlist::LogicGate


		def create_simulation_file_for_model (modelName = nil, quiet: false)
			modelName = first_model.name if modelName.nil?
			dedel = get_model_by_name(modelName)
			if dedel.nil?
				abort "ERROR: Model \"#{modelName}\" not found."
			end
			if dedel.is_self_contained? then
				model = dedel
			else
				model = flatten(modelName, false, quiet: quiet)
			end

			className = (model.name + '_simulation_class').gsub('_',' ').split.collect{|word| word.capitalize}.join
			gateArray = model.simulation_components_to_schedule_stack(withOutputGraphviz: false, quiet: quiet) # This array does not contain constants
			latchArray = model.components.select{|comp| comp.isLatch?}
			nbGates = gateArray.length
			nbLatches = latchArray.length
			nbNets = model.nets.length

			# Find inputs #
			simInputs = {} # {name -> [[net, index], ... ], ... }
			model.inputs.each do |iIO|
				iname = iIO.name
				match = iname.match(/(.*?)((\[(\d+)\])|(_(\d+)_))/)
				if match.nil? then
					simInputs[iname] = [] if simInputs[iname].nil?
					simInputs[iname] << [iIO.net, 0]
				else
					unless match[4].nil? then
						indNum = match[4].to_i
					end
					unless match[6].nil? then
						indNum = match[6].to_i
					end
					simInputs[match[1]] = [] if simInputs[match[1]].nil?
					simInputs[match[1]] << [iIO.net, indNum]
				end
			end
			simVectorInputs = [] # [[name, [net0, net1, ... ]], ... ]
			simInputs.each do |vectName, net_index_array|
				net_index_array.sort!{|net_indexA, net_indexB| net_indexA[1] <=> net_indexB[1]}
				simVectorInputs << [vectName, net_index_array.collect{|net_index| net_index[0]}]
			end

			# Find outputs #
			simOutputs = {} # {name -> [[net, index], ... ], ... }
			model.outputs.each do |iIO|
				oname = iIO.name
				match = oname.match(/(.*?)((\[(\d+)\])|(_(\d+)_))/)
				if match.nil? then
					simOutputs[oname] = [] if simOutputs[oname].nil?
					simOutputs[oname] << [iIO.net, 0]
				else
					unless match[4].nil? then
						indNum = match[4].to_i
					end
					unless match[6].nil? then
						indNum = match[6].to_i
					end
					simOutputs[match[1]] = [] if simOutputs[match[1]].nil?
					simOutputs[match[1]] << [iIO.net, indNum]
				end
			end
			simVectorOutputs = [] # [[name, [net0, net1, ... ]], ... ]
			simOutputs.each do |vectName, net_index_array|
				net_index_array.sort!{|net_indexA, net_indexB| net_indexA[1] <=> net_indexB[1]}
				simVectorOutputs << [vectName, net_index_array.collect{|net_index| net_index[0]}]
			end


			str = "/#{'*'*78}/\n\n\n"

			str += "class #{className} : public Model\n{\n" 
			str += "\tprivate:\n\n" 
			str += "\t\tstatic const unsigned int nbNets    = #{nbNets};\n"
			str += "\t\tstatic const unsigned int nbLatches = #{nbLatches};\n"
			str += "\t\tstatic const unsigned int nbGates   = #{nbGates};\n\n"
			str += "\t\tNet   *nets[nbNets];\n"
			str += "\t\tLatch *latches[nbLatches];\n"
			str += "\t\tGate  *gates[nbGates];\n\n"
			str += "\t\tbool   gateChanged[nbGates];\n\n"
			str += "\tpublic:\n\n"
			str += "\t\t#{className}();\n"
			str += "\t\t~#{className}();\n\n"
			simInputs.each do |key, val|
				val.each do |net_index|
					ind = model.nets.index(net_index[0])
					next if ind.nil?
					str += "\t\tNet *INPUT_NET_#{key}#{if val.length > 1 then "_#{net_index[1]}" end};\n"
				end
			end
			str += "\n"
			simOutputs.each do |key, val|
				val.each do |net_index|
					str += "\t\tNet *OUTPUT_NET_#{key}#{if val.length > 1 then "_#{net_index[1]}" end};\n"
				end
			end
			unless simVectorInputs.empty? then
				str += "\n"
				simVectorInputs.each do |simVectInput|
					next if simVectInput[1].collect{|net| model.nets.index(net)}.include?(nil)
					str += "\t\tBitVector *INPUT_VECTOR_#{simVectInput[0]};\n"
				end
			end
			unless simVectorOutputs.empty? then
				str += "\n"
				simVectorOutputs.each do |simVectOutput|
					str += "\t\tBitVector *OUTPUT_VECTOR_#{simVectOutput[0]};\n"
				end
			end
			str += "\n\tprivate:\n\n\t\tvoid setConstants();\n"
			str += "};\n\n"

			str += "#{className}::#{className}() :\n"
			str += "\tModel(nbNets, nbLatches, nbGates)\n"
			str += "{\n"
			model.nets.each_with_index do |net, i|
				fanouts = []
				net.fanouts.each do |fanout| 
					index = gateArray.index(fanout.target)
					fanouts << index unless index.nil?
				end
				if fanouts.empty? then
					str += "\tnets[#{i}] = new Net(NULL, 0, gateChanged);\n"
				else
					str += "\tnets[#{i}] = new Net(new int[#{fanouts.length}] {#{fanouts.collect{|ind| ind.to_s}.join(', ')}}, #{fanouts.length}, gateChanged);\n"
				end
			end
			str += "\n"
			latchArray.each_with_index do |latch, i|
				str += "\tlatches[#{i}] = new Latch(nets[#{model.nets.index(latch.input)}], nets[#{model.nets.index(latch.output)}], #{latch.initValue != 1 ? '0' : '1'});\n"
			end
			str += "\n"
			gateArray.each_with_index do |gate, i|
				str += "\tgates[#{i}] = new Gate(new Net*[#{gate.inputs.length}]{#{gate.inputs.collect{|net| "nets[#{model.nets.index(net)}]"}.join(', ')}}, #{gate.inputs.length}, nets[#{model.nets.index(gate.output)}], new uint32_t[#{((2**gate.inputs.length)/32.0).ceil}]{#{gate.get_simulation_table}});\n"
			end
			str += "\n"
			str += "\tfor (unsigned int i(0); i < nbGates; i++) {\n\t\tgateChanged[i] = false;\n\t}\n"
			str += "\n"
			simInputs.each do |key, val|
				val.each do |net_index|
					ind = model.nets.index(net_index[0])
					next if ind.nil?
					str += "\tINPUT_NET_#{key}#{if val.length > 1 then "_#{net_index[1]}" end} = nets[#{ind}];\n"
				end
			end
			str += "\n"
			simOutputs.each do |key, val|
				val.each do |net_index|
					str += "\tOUTPUT_NET_#{key}#{if val.length > 1 then "_#{net_index[1]}" end} = nets[#{model.nets.index(net_index[0])}];\n"
				end
			end
			unless simVectorInputs.empty? then
				str += "\n"
				simVectorInputs.each do |simVectInput|
					next if simVectInput[1].collect{|net| model.nets.index(net)}.include?(nil)
					str += "\tINPUT_VECTOR_#{simVectInput[0]} = new BitVector(new Net*[#{simVectInput[1].length}]{#{simVectInput[1].collect{|net| "nets[#{model.nets.index(net)}]"}.join(', ')}}, #{simVectInput[1].length});\n"
				end
			end
			unless simVectorOutputs.empty? then
				str += "\n"
				simVectorOutputs.each do |simVectOutput|
					str += "\tOUTPUT_VECTOR_#{simVectOutput[0]} = new BitVector(new Net*[#{simVectOutput[1].length}]{#{simVectOutput[1].collect{|net| "nets[#{model.nets.index(net)}]"}.join(', ')}}, #{simVectOutput[1].length});\n"
				end
			end
			str += "\n"
			str += "\tModel::setNets(nets);\n"
			str += "\tModel::setLatches(latches);\n"
			str += "\tModel::setGates(gates);\n"
			str += "\tModel::setChanges(gateChanged);\n"
			str += "}\n\n\n"

			str += "#{className}::~#{className}()\n"
			str += "{\n"
			str += "\tunsigned int i;\n\n"
			if nbNets > 0 then
				str += "\tfor (i = 0; i < nbNets; i++) {\n"
				str += "\t\tdelete nets[i];\n"
				str += "\t}\n\n"
			end
			if nbLatches > 0 then
				str += "\tfor (i = 0; i < nbLatches; i++) {\n"
				str += "\t\tdelete latches[i];\n"
				str += "\t}\n\n"
			end
			if nbGates > 0 then
				str += "\tfor (i = 0; i < nbGates; i++) {\n"
				str += "\t\tdelete gates[i];\n"
				str += "\t}\n"
			end
			unless simVectorInputs.empty? then
				str += "\n"
				simVectorInputs.each do |simVectInput|
					next if simVectInput[1].collect{|net| model.nets.index(net)}.include?(nil)
					str += "\tdelete INPUT_VECTOR_#{simVectInput[0]};\n"
				end
			end
			unless simVectorOutputs.empty? then
				str += "\n"
				simVectorOutputs.each do |simVectOutput|
					str += "\tdelete OUTPUT_VECTOR_#{simVectOutput[0]};\n"
				end
			end
			str += "}\n\n\n"
			str += "void #{className}::setConstants()\n{\n"
			model.components.select{|comp| comp.isGate? and comp.is_constant?}.each do |cstGate|
				if cstGate.singleOutputCoverList.empty? or cstGate.singleOutputCoverList[0][1] == 0 then
					str += "\tnets[#{model.nets.index(cstGate.output)}]->setValue(0);\n"
				else
					str += "\tnets[#{model.nets.index(cstGate.output)}]->setValue(1);\n"
				end
				if cstGate.singleOutputCoverList.length > 1 and cstGate.singleOutputCoverList.collect{|ina_o| ina_o[1]}.uniq.length > 1 then
					abort "ERROR: Bad constant definition in gate \"#{cstGate.output.name}\""
				end
			end
			str += "}\n\n"


			outFileName = model.name + '_cpp_sim.cc'
			File.write(outFileName, File.read(File.join(File.dirname(File.expand_path(__FILE__)), '..', '..', 'share', 'blimulator_cpp_classes.cc')) + str)
			puts "Written C++ simulation model in file \"#{outFileName}\"" unless quiet

			compileLine = "g++ -c -W -Wall -O3 -std=c++11 #{outFileName} -o #{File.basename(outFileName, '.cc')}.o"
			puts "Compiling model...\n#{compileLine}" unless quiet
			case system(compileLine)
			when nil then
				abort "ERROR: No g++ compiler found"
			when false then
				abort "An error occured during compilation"
			end


			## Header ##
			hstr  = "class #{className} : public Model\n{\n" 
			hstr += "\tprivate:\n\n" 
			hstr += "\t\tstatic const unsigned int nbNets    = #{nbNets};\n"
			hstr += "\t\tstatic const unsigned int nbLatches = #{nbLatches};\n"
			hstr += "\t\tstatic const unsigned int nbGates   = #{nbGates};\n\n"
			hstr += "\t\tNet   *nets[nbNets];\n"
			hstr += "\t\tLatch *latches[nbLatches];\n"
			hstr += "\t\tGate  *gates[nbGates];\n\n"
			hstr += "\t\tbool   gateChanged[nbGates];\n\n"
			hstr += "\tpublic:\n\n"
			hstr += "\t\t#{className}();\n"
			hstr += "\t\t~#{className}();\n\n"
			simInputs.each do |key, val|
				val.each do |net_index|
					ind = model.nets.index(net_index[0])
					next if ind.nil?
					hstr += "\t\tNet *INPUT_NET_#{key}#{if val.length > 1 then "_#{net_index[1]}" end};\n"
				end
			end
			hstr += "\n"
			simOutputs.each do |key, val|
				val.each do |net_index|
					hstr += "\t\tNet *OUTPUT_NET_#{key}#{if val.length > 1 then "_#{net_index[1]}" end};\n"
				end
			end
			unless simVectorInputs.empty? then
				hstr += "\n"
				simVectorInputs.each do |simVectInput|
					next if simVectInput[1].collect{|net| model.nets.index(net)}.include?(nil)
					hstr += "\t\tBitVector *INPUT_VECTOR_#{simVectInput[0]};\n"
				end
			end
			unless simVectorOutputs.empty? then
				hstr += "\n"
				simVectorOutputs.each do |simVectOutput|
					hstr += "\t\tBitVector *OUTPUT_VECTOR_#{simVectOutput[0]};\n"
				end
			end
			hstr += "\n\tprivate:\n\n\t\tvoid setConstants();\n"
			hstr += "};\n\n#endif /* #{model.name.upcase}_SIMULATION_HEADER_H */\n"

			hhstr = "#ifndef #{model.name.upcase}_SIMULATION_HEADER_H\n#define #{model.name.upcase}_SIMULATION_HEADER_H\n\n"
			outHeadername = model.name + '_cpp_header.hh'
			File.write(outHeadername, hhstr + File.read(File.join(File.dirname(File.expand_path(__FILE__)), '..', '..', 'share', 'blimulator_cpp_classes.hh')) + hstr)

			puts "Written C++ model simulation header in file \"#{outHeadername}\"" unless quiet
			puts "Now you can write your testbench in a C++ file as 'testbench.cc' including '#include \"#{outHeadername}\"', then run:" unless quiet
			puts "g++ -W -Wall -O3 #{File.basename(outFileName, '.cc')}.o testbench.cc" unless quiet
		end


	end # BlifUtils::Netlist

end # BlifUtils

