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

			##
			# Returns the logic level of the circuit, nil if the model includes subcircuits, or false if the model contains combinatorial loops
			def level
				return nil unless self.is_self_contained?

				graph = BlifUtils::NetlistGraph::Graph::create_from_model(self)

				start_vertices = graph.vertices.select{|v| v.component.kind_of?(BlifUtils::Netlist::Latch) or v.component.output.isOutput}.uniq

				res = catch(:combinatorial_loop_found) do 
					theMax = 0
					visited_vertices = []
					start_vertices.each do |start|
						follow_combinatorial_path(graph, start, visited_vertices)
						theMax = start.layer if start.layer > theMax
					end
					theMax
				end

				return false unless res
				return res
			end


			private


			def follow_combinatorial_path (graph, vertice, visited_vertices)
				return unless vertice.layer.nil?
				throw :combinatorial_loop_found if visited_vertices.include?(vertice)
				visited_vertices << vertice

				if vertice.component.kind_of?(BlifUtils::Netlist::Latch) then
					my_layer = 0
				else
					my_layer = 1
				end

				the_max = 0

				vertice.predecessors.each do |svert|
					next if (svert == :input or svert == :output or svert.component.kind_of?(BlifUtils::Netlist::Latch))
					follow_combinatorial_path(graph, svert, visited_vertices) if svert.layer.nil?
					the_max = [the_max, svert.layer].max
				end

				vertice.layer = my_layer + the_max
			end


			public


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

