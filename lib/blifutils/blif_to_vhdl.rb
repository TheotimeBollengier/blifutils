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


require 'blifutils/netlist'


module BlifUtils

	class Netlist

		def create_vhdl_files (topLevelModuleName = nil)
			if topLevelModuleName then
				tLModel = get_model_by_name(topLevelModuleName)
			else
				tLModel = first_model
			end

			abort "ERROR: create_vhdl_file(#{topLevelModuleName}): cannot find top level model" if tLModel.nil?

			update_clocks()

			models.each do |model| 
				model.create_vhdl_file(model == tLModel)
			end
		end 


		class Model

			def create_vhdl_file (topLevel = false)
				return if @isBlackBox
				fileName = @name + '.vhd'
				file = File.open(fileName, 'w')

				to_vhdl(toplevel: topLevel, stream: file)

				file.close
				STDERR.puts "File \"#{fileName}\" written."
			end


			def to_vhdl (topLevel: false, stream: "")
				iNames = @inputs.collect{|io| io.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'')}
				oNames = @outputs.collect{|io| io.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'')}
				just = [([0] + iNames.collect{|name| name.length}).max + 3, ([0] + oNames.collect{|name| name.length}).max + 4].max
				entityStr = iNames.collect{|name| "#{(name + '_in').ljust(just)} : in  std_ulogic;"} + 
					oNames.collect{|name| "#{(name + '_out').ljust(just)} : out std_ulogic;"}

				stream << "\nlibrary IEEE;\nuse IEEE.STD_LOGIC_1164.ALL;\n\n\nentity #{@name.upcase} is\n\tport ( "
				stream << entityStr.join("\n\t       ").chop
				stream << ");\nend #{name.upcase};\n\n\n"
				stream << "architecture blif of #{name.upcase} is\n\n"

				just = @nets.collect{|net| net.name.length}.max

				@clocks.reject{|clkname| @nets.collect{|net| net.name}.include?(clkname)}.each do |name|
					stream << "\tsignal #{name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'').ljust(just)} : std_ulogic;\n"
				end
				@nets.each do |net|
					name = net.name
					stream << "\tsignal #{name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'').ljust(just)} : std_ulogic#{if net.driver.kind_of?(BlifUtils::Netlist::Latch) and net.driver.initValue <= 1 then " := '#{net.driver.initValue}'" end};\n"
				end

				stream << "\nbegin\n\n"

				@inputs.each do |io|
					stream << "\t#{io.net.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'')} <= #{io.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'') + '_in'};\n"
				end
				stream <<("\n") unless @inputs.empty?
				@outputs.each do |io|
					stream << "\t#{io.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'') + '_out'} <= #{io.net.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'')};\n"
				end
				stream <<("\n") unless @outputs.empty?

				stream <<("\n")

				latches = @components.select{|comp| comp.kind_of?(BlifUtils::Netlist::Latch)}
				unless latches.empty? then
					clks = latches.collect{|latch| latch.ctrlSig}.reject{|el| el.nil?}.collect{|ctrlsig| if ctrlsig.kind_of?(String) then ctrlsig else ctrlsig.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'') end}.uniq

					clks.each do |clkname|
						stream << "\tprocess(#{clkname.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'')})\n\tbegin\n\t\tif rising_edge(#{clkname.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'')}) then\n"
						latches.select{|latch| latch.ctrlSig != nil and (latch.ctrlSig == clkname or latch.ctrlSig.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'') == clkname)}.each do |latch|
							stream << "\t\t\t#{latch.output.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'')} <= #{latch.input.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'')};\n"
						end
						stream << "\t\tend if;\n\tend process;\n"
					end

					if clks.empty? then
						stream << "\n\tprocess(_clk)\n\tbegin\n\t\tif rising_edge(_clk) then\n"
						latches.select{|latch| latch.ctrlSig.nil?}.each do |latch|
							stream << "\n\t\t\t#{latch.output.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'')} <= #{latch.input.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'')};\n"
						end
						stream << "\t\tend if;\n\tend process;\n"
					end
					stream <<("\n")
				end

				gates = @components.select{|comp| comp.kind_of?(BlifUtils::Netlist::LogicGate)}
				gates.each do |gate|
					next if gate.is_constant?
					oname = gate.output.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'')
					inames = gate.inputs.collect{|net| net.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'')}
					stream << "\t#{oname} <= "
					polarity = gate.singleOutputCoverList.collect{|inputs_output| inputs_output[1]}.uniq
					if polarity.length != 1 or (polarity[0] != 0 and polarity[0] != 1) then
						abort "ERROR: Output cover list of gate \"#{oname}\" contains '1' and '0' as output!"
					end
					stream <<("not(") if polarity[0] == 0 
					socvlst = gate.singleOutputCoverList.collect { |cvlst|
						cvlstArr = []
						cvlst[0].each_with_index { |val, i|
							if val == 1 then
								cvlstArr << inames[i]
							elsif val == 0 then
								cvlstArr << "not(#{inames[i]})"
								#else
								#	cvlstArr << "'1'"
							end
						}
						'(' + cvlstArr.join(' and ') + ')'
					}.join(" or\n\t#{' '*oname.length}    ")
					stream << socvlst
					stream <<(")") if polarity[0] == 0 
					stream <<(";\n")
				end
				stream <<("\n") unless gates.empty?

				constants = gates.select{|gate| gate.is_constant?}
				constants.each do |cstGate|
					oname = cstGate.output.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'')
					if cstGate.singleOutputCoverList.empty? or cstGate.singleOutputCoverList[0][2] == 0 then
						stream << "\t#{oname} <= '0';\n"
					else
						stream << "\t#{oname} <= '1';\n"
					end
				end
				stream <<("\n") unless constants.empty?

				@components.select{|comp| comp.kind_of?(BlifUtils::Netlist::SubCircuit)}.each_with_index do |subckt, i|
					stream << "\tCMPINST#{i}: entity work.#{subckt.modelName.upcase}\n\tport map ( "

					iNames = subckt.inputFormalAcutalList.collect{|io| io.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'') + '_in'}
					oNames = subckt.outputFormalAcutalList.collect{|io| io.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'') + '_out'}
					just = ([0] + iNames.collect{|name| name.length} + oNames.collect{|name| name.length}).max

					portmapStr = subckt.inputFormalAcutalList.collect{|io| "#{(io.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'') + '_in').ljust(just)} => #{io.net.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'')},"} + 
						subckt.outputFormalAcutalList.collect{|io| "#{(io.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'') + '_out').ljust(just)} => #{io.net.name.gsub(/(\[|\])/, '_').gsub(/_$/,'').gsub(/^_/,'')},"}

					stream << portmapStr.join("\n\t           ").chop
					stream << ");\n\n"
				end

				stream << "end blif;\n\n"

				return stream
			end

		end # BlifUtils::Netlist::Model

	end # BlifUtils::Netlist

end # BlifUtils

