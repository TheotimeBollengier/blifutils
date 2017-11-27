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


module BlifUtils

	class Netlist

		class IO
			attr_reader   :name
			attr_accessor :net

			def initialize (name, net)
				@name = name
				@net = net
			end

			def to_s
				return "#{if @net.isInput then 'Input' elsif @net.isOutput then 'Output' else 'IO' end} #{@net.name} / #{@name}"
			end
		end # BlifUtils::Netlist::IO


		class Component
			def isGate?
				return self.kind_of?(BlifUtils::Netlist::LogicGate)
			end

			def isLatch?
				return self.kind_of?(BlifUtils::Netlist::Latch)
			end

			def isSubcircuit?
				return self.kind_of?(BlifUtils::Netlist::SubCircuit)
			end
		end # BlifUtils::Netlist::Component


		class LogicGate < Component
			attr_accessor :inputs # [Net, ... ]       inputs   output
			attr_accessor :output # Net                  |        |
			attr_reader   :singleOutputCoverList # [[[val, ...], val], ... ]  val is 0, 1 or 2 for -

			def initialize (inputs, output, single_output_cover_list)
				@inputs = inputs
				@output = output
				@singleOutputCoverList = single_output_cover_list
			end


			def input_bit_width
				return @inputs.length
			end


			def to_blif
				str = ".names #{@inputs.collect{|net| net.name}.join(' ')} #{@output.name}\n"
				@singleOutputCoverList.each do |inputs_output|
					str += "#{inputs_output[0].collect{|strbit| case strbit when 0 then '0' when 1 then '1' else '-' end}.join}#{unless inputs_output[0].empty? then ' ' end}#{inputs_output[1]}\n"
				end
				return str
			end


			def is_buffer?
				return (@inputs.length == 1 and @singleOutputCoverList.length == 1 and @singleOutputCoverList[0][0][0] == 1 and @singleOutputCoverList[0][1] == 1)
			end


			def is_constant?
				return (@inputs.length == 0)
			end


			def to_s
				return "Logic Gate \"#{@output.name}\""
			end


			def get_LookUpTable
				outputCovered = @singleOutputCoverList.collect{|inputs_output| inputs_output[1]}.uniq
				if outputCovered.length != 1 then
					abort "ERROR: Output cover list of gate \"#{@output.name}\" covers 1 and 0:\n#{@singleOutputCoverList.collect{|ins_out| "       #{ins_out[0].collect{|ins| ins.to_s}.join.gsub('2','-')} #{ins_out[1]}\n"}.join}"
				end

				statedVal = outputCovered[0]
				if statedVal == 0 then
					defaultVal = 1
				else 
					defaultVal = 0
				end

				tableLength = 2**(@inputs.length)
				#table = (0 ... tableLength).collect{defaultVal}
				table = Array.new(tableLength){defaultVal}

				statedIndexes = []
				@singleOutputCoverList.each{|inputs_output| statedIndexes += expand_input_cover_list(inputs_output[0])}
				statedIndexes.uniq.each{|ind| table[ind] = statedVal}

				return table
			end


			private


			def expand_input_cover_list (icl)
				# icl is an array of 0, 1 and 2 for '-' #

				expanded = []

				index = icl.index(2)
				if index.nil? then
					expanded << icl.reverse.collect{|n| n.to_s}.join.to_i(2)
				else
					newIcl1 = icl.collect{|n| n}
					newIcl2 = icl.collect{|n| n}
					newIcl1[index] = 0
					newIcl2[index] = 1
					expanded += expand_input_cover_list(newIcl1)
					expanded += expand_input_cover_list(newIcl2)
				end

				return expanded
			end

		end # BlifUtils::Netlist::LogicGate


		class Latch < Component
			attr_accessor :input     # Net
			attr_accessor :output    # Net
			attr_reader   :initValue # 0, 1, 2 for don't care and 3 for unknown
			attr_reader   :ctrlType  # :fe, :re, :ah, :al, :as
			attr_reader   :ctrlSig   # Net

			def initialize (input, output, initValue, ctrlType = :re, ctrlSig = nil)
				@input = input
				@output = output
				@initValue = initValue
				@ctrlType = ctrlType
				@ctrlSig = ctrlSig
			end


			def to_blif
				return ".latch #{@input.name} #{@output.name} #{@ctrlType} #{@ctrlSig.nil? ? 'NIL' : @ctrlSig} #{@initValue}\n"
			end


			def inputs
				return [@input]
			end


			def name
				return @output.name
			end


			def to_s
				return "Latch \"#{@output.name}\""
			end

		end # BlifUtils::Netlist::Latch


		class SubCircuit < Component
			attr_reader   :modelName              # String
			attr_accessor :inputFormalAcutalList  # [IO, ... ]
			attr_accessor :outputFormalAcutalList # [IO, ... ]

			def initialize (modelName, inputFormalAcutalList, outputFormalAcutalList)
				@modelName = modelName
				@inputFormalAcutalList = inputFormalAcutalList
				@outputFormalAcutalList = outputFormalAcutalList
			end


			def to_blif
				str = ''
				tmpstr = ".subckt #{@modelName}"
				@inputFormalAcutalList.collect{|io| " #{io.name}=#{io.net.name}"}.each do |fa|
					if tmpstr.length + fa.length + 1 > 80 then
						tmpstr += " \\\n"
						str += tmpstr
						tmpstr = ''
					end
					tmpstr += fa
				end
				@outputFormalAcutalList.collect{|io| " #{io.name}=#{io.net.name}"}.each do |fa|
					if tmpstr.length + fa.length + 1 > 80 then
						tmpstr += " \\\n"
						str += tmpstr
						tmpstr = ''
					end
					tmpstr += fa
				end
				str += tmpstr + "\n"
				return str
			end


			def to_s
				return "Sub Circuit \"#{@modelName}\""
			end

		end # BlifUtils::Netlist::SubCircuit


		class Fanout
			attr_accessor :target # Component
			attr_accessor :index  # Integer

			def initialize (target, index)
				@target = target
				@index = index
			end
		end # BlifUtils::Netlist::Fanout


		class Net
			attr_accessor :name     # String
			attr_accessor :driver   # Component
			attr_accessor :fanouts  # [Fanout, ... ]
			attr_accessor :isInput  # true/false
			attr_accessor :isOutput # true/false

			def initialize (name, driver, fanouts, isInput, isOutput)
				@name = name
				@driver = driver
				@fanouts = fanouts
				@isInput = isInput
				@isOutput = isOutput
			end


			def to_s
				return @name
			end


			def isIO?
				return (@isInput or @isOutput)
			end

		end # BlifUtils::Netlist::Net


		class Model
			attr_reader   :name       # String
			attr_reader   :inputs     # [IO, ... ]
			attr_reader   :outputs    # [IO, ... ]
			attr_accessor :components # [Component, ... ]
			attr_accessor :nets       # [Net, ... ]
			attr_accessor :clocks     # [Net, ... ]
			attr_reader   :isBlackBox

			def initialize (name, inputs, outputs, components, nets, clocks, isBlackBox = false)
				@name = name
				@inputs = inputs
				@outputs = outputs
				@components = components
				@nets = nets
				@isBlackBox = isBlackBox
				@clocks = clocks
			end


			def is_blackbox?
				return not(not(@isBlackBox))
			end


			def analyze
				bannerTitle = " #{@isBlackBox ? 'Black box' : 'Model'} \"#{@name}\" analysis "
				bannerSize = [40, bannerTitle.length].max
				str  = '+' + ''.ljust(bannerSize,'-') + "+\n"
				str += '|' + bannerTitle.center(bannerSize) + "|\n"
				str += '+' + ''.ljust(bannerSize,'-') + "+\n"
				str += "#{@isBlackBox ? 'Black box' : 'Model'} \"#{@name}\"\n"
				str += "  Inputs: #{@inputs.length}\n"
				str += "  Outputs: #{@outputs.length}\n"
				return str if @isBlackBox
				str += "  Nets: #{@nets.length}\n"
				str += "  Edges: #{@nets.collect{|net| net.fanouts.length}.inject(:+)}\n"
				str += "  Nodes: #{@components.length}\n"
				str += "    Latches: #{@components.select{|comp| comp.isLatch?}.length}\n"
				gates = @components.select{|comp| comp.isGate?}
				nbGates = gates.length
				str += "    Logic gates: #{nbGates}\n"
				subcircuits = @components.select{|comp| comp.isSubcircuit?}
				nbSubcircuits = subcircuits.length
				str += "    Sub circuits: #{nbSubcircuits}\n"

				if nbGates > 0 then
					str += "  Gates repartition:\n"
					repartition = Hash.new(0)
					gates.each{|gate| repartition[gate.inputs.length] += 1}
					Hash[repartition.sort].each do |key, val|
						str += "    #{key.to_s.rjust(2)} input#{key > 1 ? 's:' : ': '} #{val.to_s.rjust(4)} #{(val*100/(nbGates.to_f)).round(1).to_s.rjust(5)}%\n"
					end

					nbBuffers = gates.select{|gate| gate.is_buffer?}.length
					nbConstants = gates.select{|gate| gate.is_constant?}.length
					str += "    Buffers:   #{nbBuffers}\n" if nbBuffers > 0
					str += "    Constants: #{nbConstants}\n" if nbConstants > 0
				end

				if nbSubcircuits > 0 then
					str += "  Sub circuits repartition:\n"
					repartition = Hash.new(0)
					subcircuits.each{|subckt| repartition[subckt.modelName] += 1}
					repartition.sort_by{|key, val| val}.each do |key_val|
						str += "    #{key_val[0]}: #{key_val[1]}\n"
					end
				end

				return str
			end


			def analyze_to_hash

				res = {}
				res[:name] = String.new(@name)
				res[:nb_inputs]  = @inputs.length
				res[:nb_outputs] = @outputs.length
				res[:is_blackbox] = @isBlackBox
				return res if @isBlackBox
				res[:nb_nets]    = @nets.length
				res[:nb_edges]   = @nets.collect{|net| net.fanouts.length}.inject(:+)
				res[:nb_nodes]   = @components.length
				res[:nb_latches] = @components.count{|comp| comp.isLatch?}
				gates = @components.select{|comp| comp.isGate?}
				res[:nb_gates]    = gates.length
				res[:nb_subckt]  = @components.count{|comp| comp.isSubcircuit?}

				if res[:nb_gates] > 0 then
					repartition = {}
					gates.collect{|g| g.inputs.length}.uniq.sort.each{|n| repartition[n] = 0}
					gates.each{|gate| repartition[gate.inputs.length] += 1}
					gh = {}
					gh[:gates_per_nb_inputs] = repartition
					gh[:nb_buffers] = gates.count{|gate| gate.is_buffer?}
					gh[:nb_constants] = gates.count{|gate| gate.is_constant?}
					res[:gates] = gh
				end

				if res[:nb_subckt] > 0 then
					repartition = Hash.new(0)
					subcircuits.each{|subckt| repartition[subckt.modelName] += 1}
					res[:subckts] = repartition
				end

				return res
			end


			def is_self_contained?
				return @components.index{|comp| comp.class == BlifUtils::Netlist::SubCircuit}.nil?
			end


			def to_blif
				str  = ".model #{@name}\n"
				if @isBlackBox then
					tmpstr = ".inputs"
					unless @inputs.empty? then
						@inputs.collect{|io| io.name}.each do |iname|
							if tmpstr.length + iname.length + 3 > 80 then
								tmpstr += " \\\n"
								str += tmpstr
								tmpstr = ''
							end
							tmpstr += ' ' + iname
						end
						str += tmpstr + "\n"
					end
					tmpstr = ".outputs"
					unless @inputs.empty? then
						@outputs.collect{|io| io.name}.each do |iname|
							if tmpstr.length + iname.length + 3 > 80 then
								tmpstr += " \\\n"
								str += tmpstr
								tmpstr = ''
							end
							tmpstr += ' ' + iname
						end
						str += tmpstr + "\n"
					end
					str += ".blackbox\n.end\n"
					return str
				end
				tmpstr = ".inputs"
				unless @inputs.empty? then
					@inputs.collect{|io| io.net.name}.each do |iname|
						if tmpstr.length + iname.length + 3 > 80 then
							tmpstr += " \\\n"
							str += tmpstr
							tmpstr = ''
						end
						tmpstr += ' ' + iname
					end
					str += tmpstr + "\n"
				end
				tmpstr = ".outputs"
				unless @inputs.empty? then
					@outputs.collect{|io| io.net.name}.each do |iname|
						if tmpstr.length + iname.length + 3 > 80 then
							tmpstr += " \\\n"
							str += tmpstr
							tmpstr = ''
						end
						tmpstr += ' ' + iname
					end
					str += tmpstr + "\n"
				end
				#str += "\n"
				@components.select{|comp| comp.isSubcircuit?}.each{|subckt| str += subckt.to_blif}
				#str += "\n"
				@components.select{|comp| comp.isLatch?}.each{|latch| str += latch.to_blif}
				#str += "\n"
				@components.select{|comp| comp.isGate?}.each{|gate| str += gate.to_blif}
				str += ".end\n"
				return str
			end


			def clone
				## stack level too deep (SystemStackError) if self is too big... =(
				return Marshal.load(Marshal.dump(self))
			end


			def rename_nets
				i = 0
				@nets.each do |net|
					unless net.isInput then
						net.name = "n#{i.to_s(16).upcase}"
						i += 1
					end
				end
			end


			def add_output_buffers
				@outputs.each_with_index do |oIO, i|
					newNet = BlifUtils::Netlist::Net.new(oIO.name, nil, [BlifUtils::Netlist::Fanout.new(:output, i)], false, true)
					newBuffer = BlifUtils::Netlist::LogicGate.new([oIO.net], newNet, [[[1], 1]])
					newNet.driver = newBuffer
					fanoutIndexToDelete = oIO.net.fanouts.index{|fanout| fanout.target == :output and fanout.index == i}
					raise "Cannot find actual fanout to delete for output" if fanoutIndexToDelete.nil?
					oIO.net.fanouts[fanoutIndexToDelete].target = newBuffer
					oIO.net.fanouts[fanoutIndexToDelete].index = 0
					oIO.net.isOutput = false
					oIO.net = newNet
					@components << newBuffer
					@nets << newNet
				end
			end


			def remove_buffers
				buffers = @components.select{|comp| comp.isGate?}.select{|gate| gate.is_buffer?}

				buffers.each do |buffer|
					netA = buffer.inputs[0]
					netB = buffer.output

					netAbufferFanoutIndex = netA.fanouts.index{|fanout| fanout.target == buffer and fanout.index == 0}
					if netAbufferFanoutIndex.nil? then
						raise "Cannot find buffer fanout in net"
					end
					netA.fanouts.delete_at(netAbufferFanoutIndex)
					netB.fanouts.each do |fanout|
						if fanout.target.class == BlifUtils::Netlist::LogicGate then
							fanout.target.inputs[fanout.index] = netA
						elsif fanout.target.class == BlifUtils::Netlist::Latch then
							fanout.target.input = netA
						elsif fanout.target.class == BlifUtils::Netlist::SubCircuit then
							fanout.target.inputFormalAcutalList[fanout.index].net = netA
						elsif fanout.target == :output then
							@outputs[fanout.index].net = netA
						else
							raise "WTF?"
						end
						netA.fanouts << fanout
					end
					if netB.isOutput then
						netA.isOutput = true
					end
					@nets.delete(netB)
					@components.delete(buffer)
				end

				buffers = @components.select{|comp| comp.isGate?}.select{|gate| gate.is_buffer?}
			end

		end # BlifUtils::Netlist::Model


		def initialize
			@models = []
		end


		def models
			return @models
		end


		def first_model
			return @models[0]
		end


		def length
			return @models.length
		end


		def model_names
			return @models.collect{|mod| mod.name}
		end


		def add_model (model)
			if include?(model.name) then
				abort "ERROR: Model \"#{model.name}\" is already defined in the model collection"
			end
			@models << model
			self
		end


		def add_model_to_front (model)
			if include?(model.name) then
				abort "ERROR: Model \"#{model.name}\" is already defined in the model collection".ligth_red
			end
			@models.unshift(model)
			self
		end


		def include? (model)
			if model.class == String then
				return model_names.include?(model)
			elsif model.class == BlifUtils::Netlist::Model then
				return @models.include?(model)
			end
		end


		def remove_model (model)
			if model.class == String then
				@models.delete_if{|momo| momo.name == model}
			elsif model.class == BlifUtils::Netlist::Model then
				@models.delete(model)
			end
			self
		end


		def get_model_by_name (name)
			return @models.select{|mod| mod.name == name}[0]
		end


		def analyze
			str = "Model collection contains #{length} models\n"
			@models.each{|model| str += model.analyze}
			return str
		end


		def remove_unused_models
			used_models = []
			find_used_models_recursive(used_models, first_model)
			model_names.each do |modName|
				unless used_models.include?(modName) then
					remove_model(modName)
				end
			end
			self
		end


		def to_blif
			return @models.collect{|mod| mod.to_blif}.join("\n")
		end


		def flatten (modelName = nil, withOutputBuffers = true, quiet: false)
			modelName = first_model.name if modelName.nil?
			dedel = get_model_by_name(modelName)
			if dedel.nil?
				abort "ERROR: Model \"#{modelName}\" not found."
			end
			if dedel.is_self_contained? then
				return dedel.clone
			end
			####################################
			update_clocks()
			####################################
			flattenedModel = flatten_model_recursive(modelName, [], quiet: quiet)
			flattenedModel.remove_buffers
			flattenedModel.rename_nets
			flattenedModel.add_output_buffers if withOutputBuffers
			return flattenedModel
		end


		def clear
			@models = []
			self
		end


		def update_clocks
			@models.each do |model|
				update_clocks_for_model_recursive(model)
			end
			self
		end


		private


		def update_clocks_for_model_recursive (model)
			childrenClocks = []
			model.components.select{|comp| comp.isSubcircuit?}.each do |subckt|
				referencedModel = get_model_by_name(subckt.modelName)
				if referencedModel.nil? then
					STDERR.puts "WARNING: update_clocks(): Model \"#{subckt.modelName}\" referenced from model \"#{model.name}\" is not is the model collection,\n         cannot determine if it uses any clock."
					next
				end
				if referencedModel.isBlackBox then
					STDERR.puts "WARNING: update_clocks(): Model \"#{subckt.modelName}\" referenced from model \"#{model.name}\" is a black box,\n         cannot determine if it uses any clock."
					next
				end
				update_clocks_for_model_recursive(referencedModel)
				childrenClocks += referencedModel.clocks
			end
			childrenClocks.uniq!
			childrenClocks.each do |clkname|
				model.clocks << clkname unless model.clocks.include?(clkname)
			end
			model.clocks.each do |clkname|
				next if model.inputs.collect{|io| io.name}.include?(clkname)
				newClkNet = BlifUtils::Netlist::Net.new(clkname, nil, [], true, false)
				newClkIo = BlifUtils::Netlist::IO.new(clkname, newClkNet)
				model.inputs.unshift(newClkIo)
			end

			model.components.select{|comp| comp.isSubcircuit?}.each do |subckt|
				referencedModel = get_model_by_name(subckt.modelName)
				next if referencedModel.nil? or referencedModel.isBlackBox
				referencedModel.clocks.each do |clkname|
					unless (subckt.inputFormalAcutalList.collect{|io| io.name} + subckt.outputFormalAcutalList.collect{|io| io.name}).include?(clkname) then
						actualClkNet = model.inputs.find{|io| io.name == clkname}.net
						actualClkNet.fanouts << BlifUtils::Netlist::Fanout.new(subckt, 0)
						newIo = BlifUtils::Netlist::IO.new(clkname, actualClkNet)

						subckt.inputFormalAcutalList.each_with_index do |io, i|
							net = io.net
							fanout = net.fanouts.find{|fnt| fnt.target == subckt and fnt.index == i}
							raise "Trouve pas le fanout de l'IO net:#{io.net.name} name:#{io.name} de la reference:#{subckt.modelName} depuis:#{model.name}" if fanout.nil?
							fanout.index += 1
						end

						subckt.inputFormalAcutalList.unshift(newIo)
					end
				end
			end
		end


		def find_used_models_recursive (used_models, model)
			return if used_models.include?(model.name)
			used_models << model.name
			model.components.select{|comp| comp.isSubcircuit?}.collect{|subc| subc.modelName}.uniq.each do |modname|
				find_used_models_recursive(used_models, get_model_by_name(modname))
			end
		end


		def flatten_model_recursive (modelName, parentModelList, quiet: false)
			puts "Flattening model \"#{modelName}\"" unless quiet
			# Retreive the model to be flattened
			originalModToFlatten = get_model_by_name(modelName)
			if originalModToFlatten.nil? then
				errStr = "ERROR: The model collection does not contains a model named \"#{modelName}\"."
				unless parentModelList.empty? then
					instancierFileName = get_model_by_name(parentModelList[-1][0]).originFileName
					errStr += "\n       Model \"#{modelName}\" is referenced in model \"#{parentModelList[-1]}\""
				end
				abort errStr
			end
			if originalModToFlatten.isBlackBox then
				abort "ERROR: Cannot flatten black box \"#{originalModToFlatten.name}\""
			end

			# Check that there is no recursive instanciation of the same model (would get infinite loop)
			if parentModelList.include?(modelName) then
				errStr = "ERROR: Recursive reference of model \"#{modelName}\".\n       Reference stack:\n"
				parentModelList.each{|pmn| errStr += "        #{pmn}\n"}
				abort errStr
			end

			# Clone it to get a new object copy to work with
			currentModel = originalModToFlatten.clone

			# Loop on each sub circuits in the current model
			currentModel.components.select{|comp| comp.isSubcircuit?}.each do |subckt|
				next if get_model_by_name(subckt.modelName).isBlackBox

				# Get a flatten clone of the referenced model
				instanciatedModel = flatten_model_recursive(subckt.modelName, parentModelList + [currentModel.name], quiet: quiet)

				# Merge the inputs #
				instanciatedModel.inputs.each do |fio|
					# Find the IO aio whose formal corresponds to fio #
					actualIOindex = subckt.inputFormalAcutalList.index{|iaio| iaio.name == fio.name}
					if actualIOindex.nil? then
						abort "ERROR: In model \"#{currentModel.name}\": in reference to model \"#{instanciatedModel.name}\": input \"#{fio.name}\" is not driven."
					end
					aio = subckt.inputFormalAcutalList[actualIOindex]
					# aio.net -> fio.net
					newBuffer = BlifUtils::Netlist::LogicGate.new([aio.net], fio.net, [[[1], 1]])
					aFanoutIndexToDelete = aio.net.fanouts.index{|fanout| fanout.target == subckt and fanout.index == actualIOindex}
					#####################################################################################
					raise "Cannot find actual fanout to delete for input" if aFanoutIndexToDelete.nil?
					aio.net.fanouts[aFanoutIndexToDelete].target = newBuffer
					aio.net.fanouts[aFanoutIndexToDelete].index = 0
					fio.net.driver = newBuffer
					fio.net.isInput = false
					currentModel.components << newBuffer
					#####################################################################################
					#unless aFanoutIndexToDelete.nil? then
					#	aio.net.fanouts[aFanoutIndexToDelete].target = newBuffer
					#	aio.net.fanouts[aFanoutIndexToDelete].index = 0
					#	fio.net.driver = newBuffer
					#	fio.net.isInput = false
					#	currentModel.components << newBuffer
					#end
					#####################################################################################
				end

				# Merge the outputs #
				instanciatedModel.outputs.each_with_index do |fio, oind|
					# Find the IO aio whose formal corresponds to fio #
					actualIOindex = subckt.outputFormalAcutalList.index{|iaio| iaio.name == fio.name}
					if actualIOindex.nil? then
						abort "ERROR: In model \"#{currentModel.name}\": in reference to model \"#{instanciatedModel.name}\": output \"#{fio.name}\" has no fanout."
					end
					aio = subckt.outputFormalAcutalList[actualIOindex]
					# fio.net -> aio.net
					newBuffer = BlifUtils::Netlist::LogicGate.new([fio.net], aio.net, [[[1], 1]])
					fFanoutIndexToDelete = fio.net.fanouts.index{|fanout| fanout.target == :output and fanout.index == oind}
					raise "Cannot find actual fanout to delete for output" if fFanoutIndexToDelete.nil?
					fio.net.fanouts[fFanoutIndexToDelete].target = newBuffer
					fio.net.fanouts[fFanoutIndexToDelete].index = 0
					aio.net.driver = newBuffer
					fio.net.isOutput = false
					currentModel.components << newBuffer
				end

				currentModel.components.delete(subckt)
				currentModel.components += instanciatedModel.components
				currentModel.nets += instanciatedModel.nets
			end

			return currentModel
		end

	end # BlifUtils::Netlist

end # BlifUtils

