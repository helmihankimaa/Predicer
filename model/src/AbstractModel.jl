#using SpineInterface
using JuMP
using Cbc
using DataFrames
using StatsPlots
using Plots
using Dates

include("structures.jl")

# Basic settings
model = JuMP.Model(Cbc.Optimizer)
set_optimizer_attributes(model, "LogLevel" => 1, "PrimalTolerance" => 1e-7)

imported_data = include(".\\import_input_data.jl")()
temporals = sort(imported_data[1])
nodes = imported_data[2]
processes = imported_data[3]
markets = imported_data[4]

stochastics = [1]

# Add all constraints, (expressions? and variables?) into a large dictionary for easier access, and being able to use the anonymous notation
# while still being conveniently accessible. 
model_contents = Dict()
model_contents["c"] = Dict() #constraints
model_contents["e"] = Dict() #expressions?
model_contents["v"] = Dict() #variables?

# Example: node balance_eq
model_contents["c"]["node_balance_eq"] = Dict()
model_contents["c"]["node_balance_eq"][("This", "is", "an", "index", "tuple")] = "@constraint(model, variable_at_index == 42)"

# reserve directions
res_dir = ["res_up", "res_down"]

# Get nodes present in reserve markets
res_nodes = []
res_tuple = []
for m in keys(markets)
    if markets[m].type == "reserve"
        push!(res_nodes,markets[m].node)
        if markets[m].direction == "up"
            for t in temporals
                push!(res_tuple,(m,markets[m].node,res_dir[1],t))
            end
        elseif markets[m].direction == "down"
            for t in temporals
                push!(res_tuple,(m,markets[m].node,res_dir[2],t))
            end
        else
            for t in temporals
                push!(res_tuple,(m,markets[m].node,res_dir[1],t))
                push!(res_tuple,(m,markets[m].node,res_dir[2],t))
            end
        end
    end
end
unique!(res_nodes)



process_tuple = []
res_potential_tuple = []
proc_online_tuple = []
# mapping flow directions of processes
for p in keys(processes), t in temporals#, sto in stochastics
    for topo in processes[p].topos
        push!(process_tuple, (p, topo[1], topo[2], t))
        if (topo[1] in res_nodes || topo[2] in res_nodes) && processes[p].is_res
            for r in res_dir
                push!(res_potential_tuple,(r,p,topo[1],topo[2],t))
            end
        end
    end
    if processes[p].is_online
        push!(proc_online_tuple, (p, t))
    end
end



# divide reserve_tuple into consumers and producers
res_pot_prod_tuple = filter(x->x[4] in res_nodes,res_potential_tuple)
res_pot_cons_tuple = filter(x->x[3] in res_nodes,res_potential_tuple)


# create variables with process_tuple
@variable(model, v_flow[tup in process_tuple] >= 0)
# if online variables exist, they are created
if !isempty(proc_online_tuple)
    @variable(model, v_online[tup in proc_online_tuple], Bin)
end
if !isempty(res_potential_tuple)
    @variable(model, v_reserve[tup in res_potential_tuple] >= 0)
end
if !isempty(res_tuple)
    @variable(model, v_res[tup in res_tuple] >= 0)
end




nod_tuple = []
node_balance_tuple = []
for n in keys(nodes), t in temporals
    if nodes[n].is_state
        push!(nod_tuple, (n, t))
    end
    if !(nodes[n].is_commodity) & !(nodes[n].is_market)
        push!(node_balance_tuple, (n,t))
    end
end
# Node state variable
@variable(model, v_state[tup in nod_tuple] >= 0)



# Dummy variables for node_states
@variable(model, vq_state_up[tup in node_balance_tuple] >= 0)
@variable(model, vq_state_dw[tup in node_balance_tuple] >= 0)

# Balance constraints
e_prod = []
e_cons = []
e_state = []
node_state_tuple = []
for (i,tu) in enumerate(node_balance_tuple)
    cons = filter(x->(x[2]==tu[1] && x[4]==tu[2]),process_tuple)
    prod = filter(x->(x[3]==tu[1] && x[4]==tu[2]),process_tuple)
    if nodes[tu[1]].is_inflow
        inflow_val = filter(x->x[1] == tu[2],nodes[tu[1]].inflow)[1][2]
    else
        inflow_val = 0.0
    end
    if isempty(cons)
        cons_expr = @expression(model, -vq_state_dw[tu] + inflow_val)
    else
        cons_expr = @expression(model, -sum(v_flow[cons]) -vq_state_dw[tu] + inflow_val)
    end
    if isempty(prod)
        prod_expr = @expression(model, vq_state_up[tu])
    else
        prod_expr = @expression(model, sum(v_flow[prod]) +vq_state_up[tu])
    end
    if nodes[tu[1]].is_state
        if tu[2]== temporals[1]
            state_expr = @expression(model, v_state[tu])
        else
            state_expr = @expression(model, v_state[tu] - v_state[node_balance_tuple[i-1]])
        end
        push!(node_state_tuple,tu)
    else
        state_expr = 0
    end
    push!(e_prod,prod_expr)
    push!(e_cons,cons_expr)
    push!(e_state,state_expr)
end
@constraint(model, node_bal_eq[(i,tup) in enumerate(node_balance_tuple)], e_prod[i] + e_cons[i] == e_state[i])
@constraint(model, node_state_max_up[(i,tup) in enumerate(node_state_tuple)], e_state[i] <= nodes[tup[1]].in_max)
@constraint(model, node_state_max_dw[(i,tup) in enumerate(node_state_tuple)], -e_state[i] <= nodes[tup[1]].in_max)
for tu in node_state_tuple
    set_upper_bound(v_state[tu],nodes[tu[1]].state_max)
end

proc_balance_tuple = []
for p in keys(processes)
    if processes[p].conversion == "1" && !processes[p].is_cf
        for t in temporals
            push!(proc_balance_tuple,(p,t))
        end
    end
end

nod_eff = []
for tup in proc_balance_tuple
    eff = processes[tup[1]].eff
    sources = filter(x->(x[1]==tup[1] && x[3]==tup[1] && x[4]==tup[2]),process_tuple)
    sinks = filter(x->(x[1]==tup[1] && x[2]==tup[1] && x[4]==tup[2]),process_tuple)
    push!(nod_eff,sum(v_flow[sinks])-eff*sum(v_flow[sources]))
end

@constraint(model, process_bal_eq[(i,tup) in enumerate(proc_balance_tuple)], nod_eff[i] == 0)

cf_balance_tuple = []
for p in keys(processes)
    if processes[p].is_cf
        push!(cf_balance_tuple,filter(x->(x[1] == p),process_tuple)...)
    end
end


cf_fac = []
for tup in cf_balance_tuple
    cf_val = filter(x->x[1] == tup[4],processes[tup[1]].cf)[1][2]
    cap = filter(x->(x[2] == tup[3]),processes[tup[1]].topos)[1][3]
    #sinks = filter(x->(x[1]==tup[1] && x[2]==tup[1] && x[4]==tup[2]),process_tuple)
    push!(cf_fac,sum(v_flow[tup])-cf_val*cap)
end

@constraint(model,cf_bal_eq[(i,tup) in enumerate(cf_balance_tuple)], cf_fac[i] == 0)

lim_tuple = []
trans_tuple = []
for p in keys(processes)
    if !processes[p].is_cf && (processes[p].conversion == "1")
        push!(lim_tuple,filter(x->x[1] == p && (x[2] == p || x[2] in res_nodes),process_tuple)...)
    elseif  processes[p].conversion == "2"
        push!(trans_tuple,filter(x->x[1] == p,process_tuple)...)
    end
end




for tup in trans_tuple
    set_upper_bound(v_flow[tup], filter(x->x[2] == tup[3], processes[tup[1]].topos)[1][3])
end
#----------------------------------




#println(filter(x->x[2] == tup[3], processes[tup[1]].topos)[1][3])
#set_upper_bound(v_flow[tup], filter(x->x[2] == tup[3], processes[tup[1]].topos)[1][3])
p_online = filter(x->processes[x[1]].is_online, lim_tuple)
p_offline = filter(x->!(processes[x[1]].is_online), lim_tuple)
p_reserve_cons = filter(x->("res_up",x...) in res_pot_cons_tuple,lim_tuple)
p_reserve_prod = filter(x->("res_up",x...) in res_pot_prod_tuple,lim_tuple)
p_noreserve = filter(x->!(x in p_reserve_cons) && !(x in p_reserve_cons),lim_tuple)
p_all = filter(x->x in p_online || x in p_reserve_cons || x in p_reserve_prod,lim_tuple)


e_lim_max = Dict(tup => AffExpr(0.0) for tup in lim_tuple)
e_lim_min = Dict(tup => AffExpr(0.0) for tup in lim_tuple)

for tup in p_reserve_prod
    add_to_expression!(e_lim_max[tup],v_reserve[("res_up",tup...)])
    add_to_expression!(e_lim_min[tup],-v_reserve[("res_down",tup...)])
end

for tup in p_reserve_cons
    add_to_expression!(e_lim_max[tup],v_reserve[("res_down",tup...)])
    add_to_expression!(e_lim_min[tup],-v_reserve[("res_up",tup...)])
end

for tup in p_online
    add_to_expression!(e_lim_max[tup],-processes[tup[1]].load_max*(processes[tup[1]].topos)[1][3]*v_online[(tup[1],tup[4])])
    add_to_expression!(e_lim_min[tup],-processes[tup[1]].load_min*(processes[tup[1]].topos)[1][3]*v_online[(tup[1],tup[4])])
end

for tup in p_offline
    if tup in p_reserve_prod || tup in p_reserve_cons
        add_to_expression!(e_lim_max[tup],-(processes[tup[1]].topos)[1][3])
    else
        set_upper_bound(v_flow[tup], (processes[tup[1]].topos)[1][3])
    end
end

con_max_tuples = filter(x->!(e_lim_max[x] == AffExpr(0)), keys(e_lim_max))
con_min_tuples = filter(x->!(e_lim_min[x] == AffExpr(0)), keys(e_lim_min))

@constraint(model,max_eq[tup in con_max_tuples],v_flow[tup]+e_lim_max[tup] <= 0)
@constraint(model,min_eq[tup in con_min_tuples],v_flow[tup]+e_lim_min[tup] >= 0)

#-----------------------------------

e_res_bal_up = []
e_res_bal_dn = []
res_eq_tuple = []
res_eq_updn_tuple = []
for n in res_nodes, t in temporals
    res_pot_u = filter(x->x[1] == res_dir[1] && x[5] == t && (x[3] == n || x[4] == n), res_potential_tuple)
    res_pot_d = filter(x->x[1] == res_dir[2] && x[5] == t && (x[3] == n || x[4] == n), res_potential_tuple)

    res_u = filter(x->x[3] == res_dir[1] && x[4] == t && x[2] == n, res_tuple)
    res_d = filter(x->x[3] == res_dir[2] && x[4] == t && x[2] == n, res_tuple)

    if !isempty(res_pot_u)
        up_lhs = @expression(model,sum(v_reserve[res_pot_u]))
    else
        up_lhs = @expression(model,0)
    end
    if !isempty(res_pot_d)
        dn_lhs = @expression(model,sum(v_reserve[res_pot_d]))
    else
        dn_lhs = 0
    end

    if !isempty(res_u)
        up_rhs = @expression(model,sum(v_res[res_u]))
    else
        up_rhs = @expression(model,0)
    end
    if !isempty(res_d)
        dn_rhs = @expression(model,sum(v_res[res_d]))
    else
        dn_rhs = @expression(model,0)
    end
    push!(e_res_bal_up, up_lhs-up_rhs)
    push!(e_res_bal_dn, dn_lhs-dn_rhs)
    push!(res_eq_tuple,(n,t))
end

for m in keys(markets), t in temporals
    if markets[m].direction == "up_down"
        push!(res_eq_updn_tuple, (m,t))
    end
end

@constraint(model,res_eq_updn[tup in res_eq_updn_tuple], v_res[(tup[1],markets[tup[1]].node,res_dir[1],tup[2])]-v_res[(tup[1],markets[tup[1]].node,res_dir[2],tup[2])] == 0)
@constraint(model,res_eq_up[(i,tup) in enumerate(res_eq_tuple)], e_res_bal_up[i] == 0)
@constraint(model,res_eq_dn[(i,tup) in enumerate(res_eq_tuple)], e_res_bal_dn[i] == 0)


#----------------------------------
cost_tup = []
cost_vec = []
market_tup = []
market_vec = []
for n in keys(nodes)
    if nodes[n].is_commodity
        push!(cost_tup,filter(x->x[2] == n,process_tuple)...)
        push!(cost_vec,map(x->x[2],nodes[n].cost)...)
    end
    if nodes[n].is_market
        price = map(x->x[2],markets[n].price)
        push!(market_tup,filter(x->x[2] == n,process_tuple)...)
        push!(market_tup,filter(x->x[3] == n,process_tuple)...)
        push!(market_vec,price...)
        push!(market_vec,-price...)
                
    end
end
if !isempty(cost_tup)
    @expression(model, commodity_costs, v_flow[cost_tup].*cost_vec)
end
if !isempty(market_tup)
    @expression(model, market_costs, v_flow[market_tup].*market_vec)
end


res_final_tuple = []
for m in keys(markets)
    if markets[m].type == "reserve"
        for t in temporals
            push!(res_final_tuple, (m, t))
        end
    end
end

@variable(model, v_res_final[tup in res_market_tup] >= 0)

model_contents["c"]["reserve_final_eq"] = Dict()
reserve_market_profits = []
for m in keys(markets)
    if markets[m].type == "reserve"
        for temp in temporals
            rf_tup = filter(t -> t[1] == m && t[2] == temp, res_final_tuple)
            r_tup = filter(t -> t[1] == m && t[4] == temp, res_tuple)
            model_contents["c"]["reserve_final_eq"][(m, temp)] = @constraint(model, sum(v_res[r_tup]) .* (m=="fcr_n" ? 0.5 : 1.0) .==  sum(v_res_final[rf_tup]))
            push!(reserve_market_profits, @expression(model, sum(v_res_final[rf_tup] .* filter(t-> t[1] == temp, markets[m].price)[1][2])))
        end
    end
end
reserve_market_costs = -1 * sum(reserve_market_profits)

# Ramp constraints
#=
function get_time_index_index(ts, t)
    for i in 1:length(ts)
        if ts[i] == t
            return i
        end
    end
    return 0
end

ramp_tuple = []
e_ramp = []
for tup in process_tuple
    if processes[tup[1]].conversion == "1" && !processes[tup[1]].is_cf && tup[1] == tup[2]
        cap = filter(x -> x[1]==tup[2] && x[2] == tup[3], processes[tup[1]].topos)[1][3]
        t = get_time_index_index(temporals, tup[4])
        if t == 1
            ramp_expr = 0
        else
            now_tup = (tup[1], tup[2], tup[3], temporals[t])
            then_tup = (tup[1], tup[2], tup[3], temporals[t - 1])
            ramp_expr = @expression(model, (v_flow[now_tup] - v_flow[then_tup]) / cap)
        end
        push!(ramp_tuple, tup)
        push!(e_ramp, ramp_expr)
    end
end

@constraint(model, process_ramp_up_eq[(i, tup) in enumerate(ramp_tuple)], e_ramp[i] <= processes[ramp_tuple[i][1]].ramp_up)
@constraint(model, process_ramp_dn_eq[(i, tup) in enumerate(ramp_tuple)], -e_ramp[i] <= processes[ramp_tuple[i][1]].ramp_down)

=#
@objective(model,Min, sum(commodity_costs)+sum(market_costs)+100000*sum(vq_state_dw.+vq_state_up)+reserve_market_costs)
optimize!(model)

v_flow_df = DataFrame(t=temporals)
v_state_df = DataFrame(t=temporals)
for tup in process_tuple
    tuple_indices = filter(x -> x[1] == tup[1] && x[2] == tup[2] && x[3] == tup[3], process_tuple)
    colname = string(tup[1:3])
    v_flow_df[!, colname] = map(x ->value.(v_flow)[tuple_indices][x], tuple_indices)
end

for tup in nod_tuple
    tuple_indices = filter(x -> x[1] == tup[1], nod_tuple)
    colname = string(tup[1])
    v_state_df[!, colname] = map(x ->value.(v_state)[tuple_indices][x], tuple_indices)
end

pt1 = @df v_flow_df plot(:t, cols(propertynames(v_flow_df)[2:2]),lw=2,xticks=Time(0):Hour(4):Time(23))
pt2 = @df v_flow_df plot(:t, cols(propertynames(v_flow_df)[3:4]),lw=2,xticks=Time(0):Hour(4):Time(23))
pt3 = @df v_flow_df plot(:t, cols(propertynames(v_flow_df)[5:7]),lw=2,xticks=Time(0):Hour(4):Time(23))
pt4 = @df v_flow_df plot(:t, cols(propertynames(v_flow_df)[8:9]),lw=2,xticks=Time(0):Hour(4):Time(23))
pt5 = @df v_flow_df plot(:t, cols(propertynames(v_flow_df)[10:11]),lw=2,xticks=Time(0):Hour(4):Time(23))
pt6 = @df v_flow_df plot(:t, cols(propertynames(v_flow_df)[12:12]),lw=2,xticks=Time(0):Hour(4):Time(23))
pt7 = @df v_state_df plot(:t, cols(propertynames(v_state_df)[2:end]),lw=2,xticks=Time(0):Hour(4):Time(23))

plot(pt1,pt2,pt3,pt4,pt5,pt6,pt7,layout=grid(7,1),size=(1000,1000),legend = :outerright)


#@expression(model, e_cons[tup in node_balance_tuple], reduce(+,v_flow[filter(x->(x[3]==tup[1] && x[4]==tup[2]),process_tuple)],init = 0)-vq_state_up[tup])

#@constraint(model, node_bal_eq[tup in node_balance_tuple], sum(v_flow[filter(x->(x[2]==tup[1] && x[4]==tup[2]),process_tuple)]) == 0)
#@constraint(model, node_bal_eq[tup in node_balance_tuple], sum(v_flow[filter(x->(x[3]==tup[1] && x[4]==tup[2]),process_tuple)]) == 0)


#e_prod = @expression(model, sum(v_flow[tup] for tup in process_tuple if tup[3]==nodes[n].name && tup[4]==t))
            
#e_cons = @expression(model, sum(-v_flow[tup] for tup in process_tuple if tup[2]==nodes[n].name && tup[4]==t))



#@expression(model, nod_test, sum(v_flow[tup] for tup in process_tuple if tup[4]=="t1"))

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