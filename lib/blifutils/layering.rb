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

	module NetlistGraph

		class Graph
			attr_accessor :vertices
			attr_reader :fromModel

			def initialize (vertices = [], model = nil)
				@vertices = vertices
				@fromModel = model
				check unless @vertices.empty?
			end


			def get_graph_without_input_output_reg_cst_modinst
				newGraph = clone
				newGraph.vertices.delete_if do |vertice|
					vertice.component == :input or
						vertice.component == :output or
						vertice.component.class == BlifUtils::Netlist::SubCircuit or
						vertice.component.class == BlifUtils::Netlist::Latch or
						(vertice.component.class == BlifUtils::Netlist::LogicGate and vertice.component.is_constant?)
				end
				newGraph.vertices.each do |vertice|
					vertice.remove_input_output_reg_cst_modinst_references
				end
				return newGraph
			end


			def clone
				vertices = @vertices.collect{|vertice| vertice.clone}
				# Update successors and predecessors references to cloned vertices
				vertices.each do |vertice|
					(0 ... vertice.successors.length).each do |i|
						next if vertice.successors[i] == :output
						successorVertice = vertices.select{|vever| vever.component == vertice.successors[i].component}
						if successorVertice.empty? then
							abort "ERROR: While cloning netlist graph: successor #{vertice.successors[i].component} of component #{vertice.component} has no reference in the graph."
						end
						if successorVertice.length > 1 then
							abort "ERROR: While cloning netlist graph: successor #{vertice.successors[i].component} of component #{vertice.component} has more than one reference in the graph."
						end
						vertice.successors[i] = successorVertice[0]
					end
					(0 ... vertice.predecessors.length).each do |i|
						next if vertice.predecessors[i] == :input
						predecessorVertice = vertices.select{|vever| vever.component == vertice.predecessors[i].component}
						if predecessorVertice.empty? then
							abort "ERROR: While cloning netlist graph: predecessor #{vertice.predecessors[i].component} of component #{vertice.component} has no reference in the graph."
						end
						if predecessorVertice.length > 1 then
							abort "ERROR: While cloning netlist graph: predecessor #{vertice.predecessors[i].component} of component #{vertice.component} has more than one reference in the graph."
						end
						vertice.predecessors[i] = predecessorVertice[0]
					end
				end
				newGraph = BlifUtils::NetlistGraph::Graph.new(vertices, @fromModel)
				return newGraph
			end


			def self.create_from_model (model)
				vertices = BlifUtils::NetlistGraph::Vertice.get_vertices_from_model(model)
				###vertices.each{|ver| puts "#{ver.component} #{ver.component.class.name} #{ver.component.label}"}
				# Update successors and predecessors references to components by references to Vertices
				vertices.each do |vertice|
					(0 ... vertice.successors.length).each do |i|
						next if vertice.successors[i] == :output
						successorVertice = vertices.select{|vever| vever.component == vertice.successors[i]}
						if successorVertice.empty? then
							abort "ERROR: While elaborating netlist graph: successor #{vertice.successors[i]} of component #{vertice.component} has no reference in the graph."
						end
						if successorVertice.length > 1 then
							abort "ERROR: While elaborating netlist graph: successor #{vertice.successors[i]} of component #{vertice.component} has more than one reference in the graph."
						end
						vertice.successors[i] = successorVertice[0]
					end
					(0 ... vertice.predecessors.length).each do |i|
						next if vertice.predecessors[i] == :input
						predecessorVertice = vertices.select{|vever| vever.component == vertice.predecessors[i]}
						if predecessorVertice.empty? then
							abort "ERROR: While elaborating netlist graph: predecessor #{vertice.predecessors[i]} of component #{vertice.component} has no reference in the graph."
						end
						if predecessorVertice.length > 1 then
							abort "ERROR: While elaborating netlist graph: predecessor #{vertice.predecessors[i]} of component #{vertice.component} has more than one reference in the graph."
						end
						vertice.predecessors[i] = predecessorVertice[0]
					end
				end
				newGraph = BlifUtils::NetlistGraph::Graph.new(vertices, model)
				return newGraph
			end


			def to_graphviz
				@vertices.each_with_index{|vert, i| vert.id = i}
				str = "digraph #{@fromModel.nil? ? '' : @fromModel.name} {\n"
				@vertices.each do |vertice|
					str += "\t#{vertice.id} [label=\"#{vertice.to_s}\""
					if vertice.component == :input or
							vertice.component == :output or
							vertice.component.class == BlifUtils::Netlist::Latch or
							(vertice.component.class == BlifUtils::Netlist::LogicGate and vertice.component.is_constant?) then
						str += ",shape=box"
					end
					str += "];\n"
				end
				@vertices.each do |vertice|
					vertice.successors.each do |successor|
						next if successor.class == Symbol
						str += "\t#{vertice.id} -> "
						str += "#{successor.id};\n"
					end
					if vertice.successors.empty? and vertice.predecessors.empty? then
						str += "\t#{vertice.id};\n"
					end
				end
				str += "}\n"
				return str
			end


			def check
				# Check that each component is in only one vertice
				allComponents = @vertices.collect{|vertice| vertice.component}
				allComponents.each do |component|
					if allComponents.select{|compo| compo == component}.length > 1 then
						abort "ERROR: Checking graph: component #{component} has more than one corresponding vertice."
					end
				end

				@vertices.each do |vertice|
					# Check that each successor has the current vertice as predecessor
					vertice.successors.each do |successor|
						next if successor == :output
						predecessorVertices = successor.predecessors.select{|prede| prede == vertice}
						if predecessorVertices.empty? then
							abort "ERROR: While elaborating netlist graph: successor #{successor.component} of component #{vertice.component} has no reference to component #{vertice.component} as predecessor."
						end
						if predecessorVertices.length > 1 then
							abort "ERROR: While elaborating netlist graph: successor #{successor.component} of component #{vertice.component} has more than one reference to component #{vertice.component} as predecessor."
						end
					end

					# Check that each predecessor has the current vertice as successor
					vertice.predecessors.each do |predecessor|
						next if predecessor == :input
						successorVertices = predecessor.successors.select{|succe| succe == vertice}
						if successorVertices.empty? then
							abort "ERROR: While elaborating netlist graph: predecessor #{predecessor.component} of component #{vertice.component} has no reference to component #{vertice.component} as successor."
						end
						if successorVertices.length > 1 then
							abort "ERROR: While elaborating netlist graph: predecessor #{predecessor.component} of component #{vertice.component} has more than one reference to component #{vertice.component} as successor."
						end
					end
				end
			end


			def get_connected_subgraphs
				dags = []

				verticePool = @vertices.collect{|vert| vert}

				until verticePool.empty? do
					newDAGvertices = []
					# Pick up a vertice
					BlifUtils::NetlistGraph::Graph.get_connected_vertices_recursive(verticePool[0], newDAGvertices, verticePool)
					dags << BlifUtils::NetlistGraph::Graph.new(newDAGvertices, @fromModel)
				end

				return dags
			end


			def is_acyclic?
				# If a directed graph is acyclic, it has at least a node with no successors,
				# if there is no such node, the graph cannot be acyclic.
				# If we remove a node with no successors, the graph is still acyclic as it leaves new nodes without successors

				# We make a copy of the graph as we will modigy it and its nodes
				graph = self.clone

				until graph.vertices.empty? do
					# Find a leaf, e.g. a node with no successors
					leafs = graph.vertices.select{|vertice| vertice.successors.empty?}
					return false if leafs.empty?
					# Remove the leaf from the graph
					leaf = leafs[0]
					graph.vertices.delete(leaf)
					leaf.predecessors.each do |predecessor|
						predecessor.successors.delete(leaf)
					end
				end

				return true
			end


			def assign_layers_to_vertices
				@vertices.each{|vertice| vertice.layer = nil}
				v_remainder_set = @vertices.collect{|vert| vert}
				u_new_set = []
				u_set_length = 0
				z_set = []
				currentLayer = 1
				while u_set_length != @vertices.length do
					selectedVertice = nil
					v_remainder_set.each do |vertice| 
						unless vertice.successors.collect{|suc| suc.layer != nil and suc.layer < currentLayer}.include?(false)
							selectedVertice = vertice
							break
						end
					end
					if selectedVertice.nil? then
						currentLayer += 1
						z_set += u_new_set
						u_new_set = []
					else
						selectedVertice.layer = currentLayer	
						u_set_length += 1
						u_new_set << selectedVertice
						v_remainder_set.delete(selectedVertice)
					end
				end
			end


			private


			def self.get_connected_vertices_recursive (vertice, newDAGvertices, verticePool)
				return if newDAGvertices.include?(vertice)
				newDAGvertices << vertice
				raise 'Mah! Que passa ?' unless verticePool.include?(vertice)
				verticePool.delete(vertice)
				vertice.predecessors.each do |predecessor|
					BlifUtils::NetlistGraph::Graph.get_connected_vertices_recursive(predecessor, newDAGvertices, verticePool)
				end
				vertice.successors.each do |successor|
					BlifUtils::NetlistGraph::Graph.get_connected_vertices_recursive(successor, newDAGvertices, verticePool)
				end
			end

		end # BlifUtils::NetlistGraph::Graph


		class Vertice
			attr_accessor :component
			attr_accessor :successors
			attr_accessor :predecessors
			attr_accessor :layer
			attr_accessor :id

			def initialize
				@component = nil
				@successors = []
				@predecessors = []
				@layer = nil
				@id = -1
			end


			def clone
				newVertice = BlifUtils::NetlistGraph::Vertice.new
				newVertice.component = @component
				newVertice.layer = @layer
				newVertice.successors = @successors.collect{|suc| suc}
				newVertice.predecessors = @predecessors.collect{|pred| pred}
				newVertice.id = @id
				return newVertice
			end


			def remove_input_output_reg_cst_modinst_references
				@successors.delete_if do |successor|
					successor == :output or
						successor.component.class == BlifUtils::Netlist::Latch
				end
				@predecessors.delete_if do |predecessor|
					predecessor == :input or
						predecessor.component.class == BlifUtils::Netlist::Latch or
						(predecessor.component.class == BlifUtils::Netlist::LogicGate and predecessor.component.is_constant?)
				end
			end


			def to_s
				return "#{@component.class.name.split('::')[-1]} (#{@component.output.name})#{@layer.nil? ? '' : " [L#{@layer}]"}"
			end


			def self.create_from_model_component (component, model)
				newVertice = BlifUtils::NetlistGraph::Vertice.new

				newVertice.component = component
				component.inputs.each do |net|
					driverCompo = net.driver
					newVertice.predecessors << driverCompo unless newVertice.predecessors.include?(driverCompo)
				end

				component.output.fanouts.each do |fanout|
					fanoutCompo = fanout.target
					newVertice.successors << fanoutCompo unless newVertice.successors.include?(fanoutCompo)
				end

				return newVertice
			end


			def self.get_vertices_from_model (model)
				vertices = model.components.collect{|component| self.create_from_model_component(component, model)}
				return vertices
			end

		end # BlifUtils::NetlistGraph::Vertice

	end # BlifUtils::NetlistGraph


	class Netlist

		class Model

			def simulation_components_to_schedule_stack (withOutputGraphviz: false, quiet: false)
				unless is_self_contained? then 
					raise "#{self.class.name}##{__method__.to_s}() requires that the model has no model reference in it. You must flatten the model before."
				end
				puts "Generating graph from model components..." unless quiet
				graphFull = BlifUtils::NetlistGraph::Graph.create_from_model(self)
				print "Extracting connected subgraphs... " unless quiet
				graphDAGs = graphFull.get_graph_without_input_output_reg_cst_modinst
				dags = graphDAGs.get_connected_subgraphs
				puts "#{dags.length} subgraph#{dags.length > 1 ? 's' : ''} found" unless quiet

				print "Checking that there are no cycles in subgraphs... " unless quiet
				# Check that all subgraphs are acyclic
				dags.each_with_index do |dag, i|
					unless dag.is_acyclic? then
						str = "\nERROR: There is a combinatorial loop.\n       (See cycle in file \"#{@name}_graph_DAG_#{i}.gv\")\n       This subgraph includes components:\n"
						dag.vertices.each do |vertice|
							str += "       Component #{vertice.to_s}\n"
						end

						abort str
					end
				end
				puts "Ok" unless quiet

				# Do graph layering
				puts "Layering subgraphs..." unless quiet
				dags.each_with_index do |dag, i|
					dag.assign_layers_to_vertices
					File.write("#{@name}_graph_DAG_#{i}.gv", dag.to_graphviz) if withOutputGraphviz
				end

				File.write("#{@name}_graph_subgraphs.gv", graphDAGs.to_graphviz) if withOutputGraphviz 
				graphDAGs.vertices.each do |vertice|
					ind = graphFull.vertices.index{|vert| vert.component == vertice.component}
					graphFull.vertices[ind].layer = vertice.layer unless ind.nil?
				end
				File.write("#{@name}_graph_full.gv", graphFull.to_graphviz) if withOutputGraphviz 
				puts "Maximum number of layers: #{dags.collect{|dag| dag.vertices.collect{|vertice| vertice.layer}.reject{|l| l.nil?}.max}.reject{|m| m.nil?}.max}" unless quiet

				puts "Writing static schedule for component simulation..." unless quiet
				componentSchedulingStack = []
				dags.each do |dag|
					dag.vertices.sort{|verta, vertb| vertb.layer <=> verta.layer}.each{|vert| componentSchedulingStack << vert.component}
				end
				unless componentSchedulingStack.index{|comp| comp.class != BlifUtils::Netlist::LogicGate}.nil? then
					raise "merde"
				end

				return componentSchedulingStack
			end

		end # BlifUtils::Netlist::Model

	end # BlifUtils::Netlist

end # BlifUtils

