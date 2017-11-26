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


require 'rltk/parser'
require_relative 'lexer.rb'
require_relative 'ast.rb'


module BlifUtils

	module BlifUtils::Language

		class Parser < RLTK::Parser

			production(:toplevel, 'model_list') do |arr| 
				BlifUtils::AST::TranslationUnit.new(arr)
			end

			list(:model_list, [:model, :file_reference])

			nonempty_list(:identifier_list, :IDENTIFIER)

			production(:model, 'MODEL .IDENTIFIER .model_header .commands END') do |name, header, commands|
				BlifUtils::AST::Model.new(name, header, commands)
			end

			list(:model_header, :model_header_element)

			production(:model_header_element) do
				clause('INPUTS .identifier_list') do |arr| 
					BlifUtils::AST::ModelHeaderElementInputs.new(arr)
				end
				clause('OUTPUTS .identifier_list') do |arr| 
					BlifUtils::AST::ModelHeaderElementOutputs.new(arr)
				end
				clause('CLOCK .identifier_list') do |arr| 
					BlifUtils::AST::ModelHeaderElementClock.new(arr)
				end
			end

			list(:commands, :command)

			production(:command) do
				clause('NAMES .identifier_list .cover_list') do |idl, cl|
					icl = cl.collect do |s|
						broken = s.split(/\s+/)
						if broken.length == 1 then
							[[], s.to_i]
						else
							[broken.first.split('').collect{|char|
								case char
								when '0' then 0
								when '1' then 1
								else 2
								end
							}, broken.last.to_i]
						end
					end
					BlifUtils::AST::LogicGate.new(idl, icl)
				end
				clause('LATCH .generic_latch')  { |gl| gl }
				clause('SUBCKT .IDENTIFIER .formal_actual_list') do |name, fal|
					BlifUtils::AST::ModelReference.new(name, fal)
				end
				clause('SEARCH .IDENTIFIER')    { |fn| BlifUtils::AST::SubfileReference.new(fn) }
				clause('BLACKBOX')              { |_|  BlifUtils::AST::BlackBox.new }
			end

			production(:generic_latch) do
				clause('IDENTIFIER IDENTIFIER LATCHTYPE IDENTIFIER LATCHINITVAL') do |input, output, type, control, init|
					BlifUtils::AST::GenericLatch.new(input, output, ctrlType: type, ctrlSig: ((control =~ /^NIL$/) ? nil : control), initValue: init)
				end
				clause('IDENTIFIER IDENTIFIER LATCHTYPE IDENTIFIER') do |input, output, type, control|
					BlifUtils::AST::GenericLatch.new(input, output, ctrlType: type, ctrlSig: ((control =~ /^NIL$/) ? nil : control))
				end
				clause('IDENTIFIER IDENTIFIER LATCHINITVAL') do |input, output, init|
					BlifUtils::AST::GenericLatch.new(input, output, initValue: init)
				end
				clause('IDENTIFIER IDENTIFIER') do |input, output|
					BlifUtils::AST::GenericLatch.new(input, output)
				end
			end

			list(:cover_list, :COVER)

			nonempty_list(:formal_actual_list, :formal_actual)

			production(:formal_actual, '.IDENTIFIER EQUAL .IDENTIFIER') { |formal, actual| [formal, actual] }

			production(:file_reference, 'SEARCH .IDENTIFIER') { |fn| BlifUtils::AST::SubfileReference.new(fn) }
			finalize()

		end # BlifUtils::Language::Parser

	end # BlifUtils::Language


	class Parser

		def self.parse (fileName, quiet: false)
			processedFileNames = []
			ast = self.parse_recursive(File.expand_path(fileName), processedFileNames, quiet)
			return ast
		end


		def self.parse_string (str, quiet: false)
			lexems = BlifUtils::Language::Lexer::lex(str)

			begin
				ast = BlifUtils::Language::Parser::parse(lexems)
			rescue RLTK::NotInLanguage => e
				print_parse_error(e.current, 'String not in grammar.')
			rescue RLTK::BadToken => e
				print_parse_error(e.faultyToken, "Unexpected token: \"#{e.faultyToken.type.to_s}\". Token not present in grammar definition.")
			end

			# Delete file references from the AST
			ast.modelList.delete_if do |elem| 
				if elem.kind_of?(BlifUtils::AST::SubfileReference) then
					STDERR.puts "WARNING: Ignoring \".search #{elem.fileName}\"" unless quiet
					true
				else
					false
				end
			end

			ast.modelList.each do |model|
				model.commands.delete_if do |com| 
					if com.kind_of?(BlifUtils::AST::SubfileReference) then
						STDERR.puts "WARNING: Ignoring \".search #{com.fileName}\"" unless quiet
						true
					else
						false
					end
				end
			end

			return ast
		end


		private


		def self.print_parse_error (token, errorString)
			unless token.position.nil? then
				fileName = token.position.file_name
				line =     token.position.line_number
				column =   token.position.line_offset

				STDERR.puts "ERROR: Parse error at line #{line}, column #{column+1}, from file \"#{fileName}\":\n#{errorString}"
				str = File.read(fileName).lines.to_a[line-1].gsub(/\t/,' ')
				STDERR.puts (line.to_s + ': ') + str
				abort ' '*(line.to_s.length + 2) + ('~'*column + '^')
			else
				STDERR.puts "Parse error:"
				abort errorString
			end
		end


		def self.parse_file (fileName, quiet = false)
			puts "Parsing file \"#{fileName}\"..." unless quiet
			lexems = BlifUtils::Language::Lexer::lex_file(fileName)

			begin
				ast = BlifUtils::Language::Parser::parse(lexems)
			rescue RLTK::NotInLanguage => e
				print_parse_error(e.current, 'String not in grammar.')
			rescue RLTK::BadToken => e
				print_parse_error(e.faultyToken, "Unexpected token: \"#{e.faultyToken.type.to_s}\". Token not present in grammar definition.")
			end

			return ast
		end


		def self.parse_recursive (fileName, processedFileNames, quiet = false)
			return BlifUtils::AST::TranslationUnit.new if processedFileNames.include?(fileName)
			processedFileNames << fileName

			# Parse the file
			ast = self.parse_file(fileName)

			# Gather new file to parse
			newFileToParseList = []
			ast.modelList.each do |element|
				if element.kind_of?(BlifUtils::AST::SubfileReference) then # file reference outside a model
					newFileToParseList << element.fileName
				else # it is a Model
					element.commands.select{|elm| elm.kind_of?(BlifUtils::AST::SubfileReference)}.each do |com|
						newFileToParseList << com.fileName
					end
				end
			end

			# Delete file references from the AST
			ast.modelList.delete_if{|elem| elem.kind_of?(BlifUtils::AST::SubfileReference)}
			ast.modelList.each do |model|
				model.commands.delete_if{|com| com.kind_of?(BlifUtils::AST::SubfileReference)}
			end

			# Get absolute path of new file to parse
			dirname = File.dirname(fileName)
			newFileToParseList.collect!{|fn| File.expand_path(fn, dirname)}

			# Parse new files
			newFileToParseList.each do |newFileName|
				newAst = self.parse_recursive(newFileName, processedFileNames, quiet)
				newAst.modelList.each do |newModel|
					if ast.modelList.collect{|model| model.name}.include?(newModel.name) then
						abort "ERROR: Model \"#{newModel.name}\" is redefined"
					end
					ast.modelList << newModel
				end
			end

			return ast
		end

	end # BlifUtils::Parser

end # BlifUtils




if __FILE__ == $0 then

	abort "Usage: #{__FILE__} <file_to_parse>" unless ARGV.length == 1

	puts BlifUtils::Parser::parse(ARGV[0]).pretty_print
end

