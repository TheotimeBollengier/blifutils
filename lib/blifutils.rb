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
	VERSION = '0.0.2'
end

require 'blifutils/parser'
require 'blifutils/netlist'
require 'blifutils/elaborator'
require 'blifutils/layering'
require 'blifutils/level_analyzer'
require 'blifutils/simulator_generator'
require 'blifutils/blif_to_vhdl'

