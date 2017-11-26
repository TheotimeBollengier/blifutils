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

		class Model

			def level_analysis (withOutputGraphviz: false, quiet: false)
				return unless is_self_contained?

				puts "Generating graph from model components..." unless quiet
				graphFull = BlifUtils::NetlistGraph::Graph.create_from_model(self)
				print "Extracting connected subgraphs... " unless quiet
				graphDAGs = graphFull.get_graph_without_input_output_reg_cst_modinst
				dags = graphDAGs.get_connected_subgraphs
				puts "#{dags.length} subgraph#{dags.length > 1 ? 's' : ''} found"

				print "Checking that there are no cycles in subgraphs...\n" unless quiet
				# Check that all subgraphs are acyclic
				dags.each_with_index do |dag, i|
					unless dag.is_acyclic? then
						str = "\nERROR: There is a combinatorial loop.\n       This subgraph includes components:\n"
						dag.vertices.each do |vertice|
							str += "       Component #{vertice.to_s}\n"
						end
						abort str
					end
				end
				puts "No combinatorial loops found"

				# Do graph layering
				unless quiet then
					print "Layering subgraphs...\n" unless withOutputGraphviz
				end
				maxDagSize = 0
				maxDagLevel = 0
				dags.each_with_index do |dag, i|
					dag.assign_layers_to_vertices
					dagSize = dag.vertices.length
					dagLevel = dag.vertices.collect{|vertice| vertice.layer}.reject{|l| l.nil?}.max
					maxDagSize = dagSize if dagSize != nil and maxDagSize < dagSize
					maxDagLevel = dagLevel if dagLevel != nil and maxDagLevel < dagLevel
					if withOutputGraphviz then
						File.write("#{@name}_graph_DAG_#{i}.gv", dag.to_graphviz)
						puts "Graph #{i.to_s.rjust(2)}: level #{dagLevel.to_s.rjust(2)}, size #{dagSize.to_s.rjust(2)}"
					end

				end

				if withOutputGraphviz then
					File.write("#{@name}_graph_subgraphs.gv", graphDAGs.to_graphviz)
					graphDAGs.vertices.each do |vertice|
						ind = graphFull.vertices.index{|vert| vert.component == vertice.component}
						graphFull.vertices[ind].layer = vertice.layer unless ind.nil?
					end
					File.write("#{@name}_graph_full.gv", graphFull.to_graphviz)
				end

				puts "Maximum number of layers: #{maxDagLevel}"
				puts "Maximum number of gate per subgraph: #{maxDagSize}"
			end # BlifUtils::Netlist::Model::level_analysis

		end # BlifUtils::Netlist::Model

	end # BlifUtils::Netlist

end # BlifUtils

