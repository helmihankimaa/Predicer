using SpineInterface
using JuMP
using Cbc

include("structures.jl")

# Basic settings
model = JuMP.Model(Cbc.Optimizer)
set_optimizer_attributes(model, "LogLevel" => 1, "PrimalTolerance" => 1e-7)

imported_data = include(".\\import_input_data.jl")()
temporals = imported_data[1]
nodes = imported_data[2]
processes = imported_data[3]
markets = imported_data[4]

stochastics = [1]


#@variable(model, node_state[keys(nodes), stochastics, temporals])

#@variable(model, v_flow[p in keys(processes), "SOURCE", "SINK", stochastics, temporals])
#t in processes[p].topos



# As per Topis contrbution to discussion:
#@variable(model, node_state[nodes, stochastics, temporals])
#@variable(model, process_flow[processes, directions, nodes, stochastics, temporals])

# in case inflow can not be balanced
#@variable(model, node_slack[nodes, stochastics, temporals])

# Esas proposal for one (NGCHP) process for example
# v_flow(process, source node(NG), process(NGCHP), stochastics, temporal)
# v_flow(process, process(NGCHP), sink node1(dh), stochastics, temporal)
# v_flow(process, process(NGCHP), sink node2(elec), stochastics, temporal)
#@variable(model, v_flow[p in processes, p.sources, p.sinks, stochastics, temporals])

# Connections are basically a simple process with a efficiency of 1 (?). No need to implement?

# Node balance constraints
#sum of process flows in and out from a node should be equal


# process flow balance constraints
    # ensure that the flows from/in to a process (?) are at equilibrium.
    # In that case also need to model exhaust/wast heat/energy as one additional flow
    # OR, just have flow_in * eff = flow_out

# node_slack constraints. Actually not needed, since the cost could be set as absolute?

# Get input data into abstract format

    #Into node / process struct format
    #Functions for each type of "special plant", such as CHP or wind, etc
    # This means, that the abstract format data can be converted into a JuMP model easily

# Translate abstract format into JuMP

    # How to do this?
    # Processes as variables, and nodes as constraints?

# Run JuMP model

# Translate results to human-readable format