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


require 'rltk/lexer'


module BlifUtils

	module BlifUtils::Language

		class Lexer < RLTK::Lexer
			# Comment rule
			rule(/#.*(?=\r?\n)/)

			# Ignore kiss state machine
			rule(/\.start_kiss/) { push_state :kiss }
			rule(/\.end_kiss/, :kiss)   { pop_state }
			rule(/./, :kiss)

			# Skip line concatenation, new lines and whitespaces
			rule(/\\\r?\n/)
			rule(/[\r\n\f\v]+\s*/)
			rule(/[ \t\r]/)

			# Command rules
			rule(/\.model/)    { :MODEL }
			rule(/\.end/)      { :END }
			rule(/\.inputs/)   { :INPUTS }
			rule(/\.outputs/)  { :OUTPUTS }
			rule(/\.clock/)    { :CLOCK }
			rule(/\.blackbox/) { :BLACKBOX }
			rule(/\.names/)    { :NAMES }
			rule(/\.latch/)    { push_state(:latch); :LATCH }
			rule(/\.subckt/)   { :SUBCKT }
			rule(/\.search/)   { :SEARCH }

			# The equal tocken for formal/actual lists
			rule(/=/) { :EQUAL }

			# Latch specific tockens
			rule(/(fe)|(re)|(ah)|(al)|(as)/, :latch) { |s| [:LATCHTYPE, s.to_sym] }
			rule(/[0123]/,                   :latch) { |s| [:LATCHINITVAL, s.to_i] }
			rule(/[^\s=]+/,                  :latch) { |s| [:IDENTIFIER, s] }
			rule(/#.*(?=\r?\n)/,             :latch)
			rule(/\\\r?\n/,                  :latch)
			rule(/[ \t\r]/,                  :latch)
			rule(/[\r\n\f\v]+\s*/,           :latch) { pop_state }

			# Names cover
			rule(/([01-]+\s+)?[01][ \t]*(?=\r?\n)/) { |s| [:COVER, s.sub(/^\s+/,'').sub(/\s+$/,'')] }

			# Ignored commands
			rule(/\.area\.*\r?\n/)
			rule(/\.cycle\.*\r?\n/)
			rule(/\.clock_event\.*\r?\n/)
			rule(/\.delay\.*\r?\n/)
			rule(/\.default_input_arrival\.*\r?\n/)
			rule(/\.default_input_drive\.*\r?\n/)
			rule(/\.default_max_input_load\.*\r?\n/)
			rule(/\.default_output_load\.*\r?\n/)
			rule(/\.default_output_required\.*\r?\n/)
			rule(/\.exdc\.*\r?\n/)
			rule(/\.gate\.*\r?\n/)
			rule(/\.input_arrival\.*\r?\n/)
			rule(/\.input_drive\.*\r?\n/)
			rule(/\.max_input_load\.*\r?\n/)
			rule(/\.mlatch\.*\r?\n/)
			rule(/\.output_required\.*\r?\n/)
			rule(/\.output_load\.*\r?\n/)
			rule(/\.wire_load_slope\.*\r?\n/)
			rule(/\.wire\.*\r?\n/)

			# Identifier
			rule(/[^\s=]+/) { |s| [:IDENTIFIER, s] }

		end # BlifUtils::Language::Lexer

	end # BlifUtils::Language

end # BlifUtils



if $0 == __FILE__ then
	ts = Time.now
	tokens = BlifUtils::Language::Lexer::lex_file(ARGV[0])
	te = Time.now

	tokens.each do |el|
		if el.value then
			puts "#{el.type.to_s} -> \"#{el.value}\""
		else
			puts "#{el.type.to_s}"
		end
	end

	puts '-'*80
	puts "Lexing time: #{te - ts} s"
	puts '-'*80

	puts "MODEL          #{tokens.count{|t| t.type == :MODEL}}"
	puts "END            #{tokens.count{|t| t.type == :END}}"
	puts "INPUTS         #{tokens.count{|t| t.type == :INPUTS}}"
	puts "OUTPUTS        #{tokens.count{|t| t.type == :OUTPUTS}}"
	puts "CLOCK          #{tokens.count{|t| t.type == :CLOCK}}"
	puts "BLACKBOX       #{tokens.count{|t| t.type == :BLACKBOX}}"
	puts "NAMES          #{tokens.count{|t| t.type == :NAMES}}"
	puts "LATCH          #{tokens.count{|t| t.type == :LATCH}}"
	puts "LATCHTYPE      #{tokens.count{|t| t.type == :LATCHTYPE}}"
	puts "LATCHINITVAL   #{tokens.count{|t| t.type == :LATCHINITVAL}}"
	puts "SUBCKT         #{tokens.count{|t| t.type == :SUBCKT}}"
	puts "SEARCH         #{tokens.count{|t| t.type == :SEARCH}}"
	puts "EQUAL          #{tokens.count{|t| t.type == :EQUAL}}"
	puts "COVER          #{tokens.count{|t| t.type == :COVER}}"
	puts "IDENTIFIER     #{tokens.count{|t| t.type == :IDENTIFIER}}"
end

