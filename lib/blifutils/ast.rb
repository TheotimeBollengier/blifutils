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

		module AST

			class TranslationUnit
				attr_reader :modelList

				def initialize (modList = [])
					@modelList = modList
				end

				def pretty_print
					ret = ''
					@modelList.each {|model| ret += model.pretty_print(0)}
					return ret
				end
			end # BlifUtils::AST::TranslationUnit


			class Model
				attr_reader :name, :header, :commands, :isBlackBox

				def initialize (name, header, commands = [])
					@name = name
					@header = header
					@commands = commands
					@isBlackBox = not(@commands.index{|command| command.class == AST::BlackBox}.nil?)
					if @isBlackBox and not(@commands.reject{|command| command.class == AST::BlackBox}.empty?) then
						STDERR.puts "WARNING: Blackbox \"#{@name}\" contains non blackbox commands"
						@commands = @commands.reject{|command| command.class == AST::BlackBox}.uniq
					end
				end

				def pretty_print (indent)
					str = '    '*indent + "#{@isBlackBox ? 'Black box' : 'Model'}:\n" + '    '*(indent+1) + "Name:    \"#{@name}\"\n"
					@header.each{|headEl| str += headEl.pretty_print(indent+1)}
					@commands.each{|com| str += com.pretty_print(indent+1)} unless @isBlackBox
					return str
				end
			end # BlifUtils::AST::Model


			class ModelHeaderElementInputs
				attr_reader :inputList

				def initialize (inputList)
					@inputList = inputList
				end

				def pretty_print (indent)
					return '    '*indent + "Inputs:  #{@inputList.collect{|str| "\"#{str}\""}.join(', ')}\n"
				end
			end # BlifUtils::AST::ModelHeaderElementInputs


			class ModelHeaderElementOutputs
				attr_reader :outputList

				def initialize (outputList)
					@outputList = outputList
				end

				def pretty_print (indent)
					return '    '*indent + "Outputs: #{@outputList.collect{|str| "\"#{str}\""}.join(', ')}\n"
				end
			end # BlifUtils::AST::ModelHeaderElementOutputs


			class ModelHeaderElementClock
				attr_reader :clockList

				def initialize (clockList)
					@clockList = clockList
				end

				def pretty_print (indent)
					return '    '*indent + "Clocks:  #{@clockList.collect{|str| "\"#{str}\""}.join(', ')}\n"
				end
			end # BlifUtils::AST::ModelHeaderElementClock


			class LogicGate
				attr_reader :inputs, :output, :single_output_cover_list

				def initialize (identifier_list, single_output_cover_list)
					@inputs = identifier_list[0 ... -1]
					@output = identifier_list[-1]
					@single_output_cover_list = single_output_cover_list
				end

				def pretty_print (indent)
					str  = '    '*indent + "Logic gate:\n"
					str += '    '*(indent+1) + "Inputs: #{@inputs.collect{|idf| "\"#{idf}\""}.join(', ')}\n"
					str += '    '*(indent+1) + "Output: \"#{@output}\"\n"
					str += '    '*(indent+1) + "Cover list:\n"
					@single_output_cover_list.each do |inputs_output|
						str += '    '*(indent+2) + "#{inputs_output[0].collect{|strbit| case strbit when 0 then '0' when 1 then '1' else '-' end}.join} | #{inputs_output[1]}\n"
					end
					return str
				end
			end # BlifUtils::AST::LogicGate


			class GenericLatch
				attr_reader :input, :output, :initValue, :ctrlType, :ctrlSig

				def initialize (input, output, initValue: nil, ctrlType: nil, ctrlSig: nil)
					@input = input
					@output = output
					@initValue = initValue
					@ctrlType = ctrlType
					@ctrlSig = ctrlSig
				end

				def pretty_print (indent)
					str  = '    '*indent + "Latch:\n"
					str += '    '*(indent+1) + "Input:  \"#{@input}\"\n"
					str += '    '*(indent+1) + "Output: \"#{@output}\"\n"
					str += '    '*(indent+1) + "Initial value: #{@initValue.nil? ? "undefined" : "\"#{@initValue}\""}\n"
					str += '    '*(indent+1) + "Type: #{@ctrlType.nil? ? "undefined" : "\"#{@ctrlSig}\""}\n"
					str += '    '*(indent+1) + "Clock signal: #{@ctrlSig.nil? ? "undefined" : "\"#{@ctrlSig}\""}\n"
					return str
				end
			end # BlifUtils::AST::GenericLatch


			class ModelReference
				attr_reader :modelName, :formalAcutalList

				def initialize (modelName, formalAcutalList)
					@modelName = modelName
					@formalAcutalList = formalAcutalList
				end

				def pretty_print (indent)
					str  = '    '*indent + "Model reference:\n"
					str += '    '*(indent+1) + "Model name: \"#{@modelName}\"\n"
					str += '    '*(indent+1) + "Formal / Actual mapping:\n"
					@formalAcutalList.each do |form_act|
						str += '    '*(indent+2) + "\"#{form_act[0]}\" -> \"#{form_act[1]}\"\n"
					end
					return str
				end
			end # BlifUtils::AST::ModelReference


			class BlackBox; end # BlifUtils::AST::BlackBox


			class SubfileReference
				attr_reader :fileName

				def initialize (fileName)
					@fileName = fileName
				end

				def pretty_print (indent)
					str  = '    '*indent + "Sub file reference: \"#{@fileName}\"\n"
					return str
				end
			end # BlifUtils::AST::SubfileReference

		end # BlifUtils::AST

end # BlifUtils

