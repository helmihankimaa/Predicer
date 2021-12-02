using DataFrames
using XLSX
using AbstractModel
function main()
    sheetnames_system = ["nodes", "processes", "process_topology", "markets"]#, "energy_market", "reserve_market"]
    sheetnames_timeseries = ["cf", "inflow", "market_prices", "price"]
    # Assuming this file is under \predicer\model
    wd = split(string(@__DIR__), "src")[1]
    input_data_path = wd * "input_data\\input_data_V3.xlsx"

    system_data = Dict()
    timeseries_data = Dict()
    timeseries_data["scenarios"] = Dict()
    scenarios = []

    for sn in sheetnames_timeseries
        timeseries_data[sn] = DataFrame(XLSX.readtable(input_data_path, sn)...)
    end

    for k in keys(timeseries_data)
        if k!="scenarios"
            for n in names(timeseries_data[k])
                if n != "t"
                    series = split(n, ", ")[1]
                    scenario = split(n, ", ")[2]
                    push!(scenarios, scenario)
                    if !(scenario in keys(timeseries_data["scenarios"]))
                        timeseries_data["scenarios"][scenario] = Dict()
                    end
                    if !(k in keys(timeseries_data["scenarios"][scenario]))
                        timeseries_data["scenarios"][scenario][k] = DataFrame(t=timeseries_data[k].t)
                    end
                    timeseries_data["scenarios"][scenario][k][!, series] = timeseries_data[k][!, n]
                end
            end
        end
    end
    scenarios = unique(scenarios)
    for sn in sheetnames_system
        system_data[sn] = DataFrame(XLSX.readtable(input_data_path, sn)...)
    end

    dates = []

    nodes = Dict()
    for i in 1:nrow(system_data["nodes"])
        n = system_data["nodes"][i, :]
        nodes[n.node] = Node(n.node, Bool(n.is_commodity), Bool(n.is_state), Bool(n.is_res), Bool(n.is_inflow), Bool(n.is_market), n.state_max, n.in_max, n.out_max)
        if Bool(n.is_commodity)
            for s in scenarios
                timesteps = timeseries_data["scenarios"][s]["price"].t
                prices = timeseries_data["scenarios"][s]["price"][!, n.node]
                ts = TimeSeries(s)
                for i in 1:length(timesteps)
                    tup = (timesteps[i], prices[i],)
                    push!(ts.series, tup)
                end
                push!(nodes[n.node].cost, ts)
                append!(dates, timesteps)
            end
        end
        if Bool(n.is_inflow)
            for s in scenarios
                timesteps = timeseries_data["scenarios"][s]["inflow"].t
                flows = timeseries_data["scenarios"][s]["inflow"][!, n.node]
                ts = TimeSeries(s)
                for i in 1:length(timesteps)
                    tup = (timesteps[i], flows[i],)
                    push!(ts.series, tup)
                end
                push!(nodes[n.node].inflow, ts)
                append!(dates, timesteps)
            end
        end
    end
    
    processes = Dict()
    for i in 1:nrow(system_data["processes"])
        p = system_data["processes"][i, :]
        processes[p.process] = Process(p.process, Bool(p.is_cf), Bool(p.is_online), Bool(p.is_res), p.eff, p.load_min, p.load_max, p.ramp_down, p.ramp_up)
        if Bool(p.is_cf)
            for s in scenarios
                timesteps = timeseries_data["scenarios"][s]["cf"].t
                cf = timeseries_data["scenarios"][s]["cf"][!, p.process]
                ts = TimeSeries(s)
                for i in 1:length(timesteps)
                    tup = (timesteps[i], cf[i],)
                    push!(ts.series, tup)
                end
                push!(processes[p.process].cf, ts)
                append!(dates, timesteps)
            end
        end
        sources = []
        sinks = []
        for j in 1:nrow(system_data["process_topology"])
            pt = system_data["process_topology"][j, :]
            if pt.process == p.process
                if pt.source_sink == "source"
                    push!(sources, (pt.node, pt.capacity, pt.VOM_cost))
                elseif pt.source_sink == "sink"
                    push!(sinks, (pt.node, pt.capacity, pt.VOM_cost))
                end
            end
        end
        if p.conversion == 1
            for so in sources
                push!(processes[p.process].topos, Topology(so[1], p.process, so[2], so[3]))
            end
            for si in sinks
                push!(processes[p.process].topos, Topology(p.process, si[1], si[2], si[3]))
            end
        elseif p.conversion == 2
            for so in sources, si in sinks
                push!(processes[p.process].topos, Topology(so[1], si[1], min(so[2], si[2]), so[3]))
            end
        elseif p.conversion == 3
            for so in sources, si in sinks
                push!(processes[p.process].topos, Topology(so[1], si[1], min(so[2], si[2]), so[3]))
                push!(processes[p.process].topos, Topology(si[1], so[1], min(so[2], si[2]), si[3]))
            end
        end
    end
    
    markets = Dict()
    for i in 1:nrow(system_data["markets"])
        mm = system_data["markets"][i, :]
        markets[mm.market] = Market(mm.market, mm.type, mm.node, mm.direction)
        #
        for s in scenarios
            timesteps = timeseries_data["scenarios"][s]["market_prices"].t
            mps = timeseries_data["scenarios"][s]["market_prices"][!, mm.market]
            ts = TimeSeries(s)
            for i in 1:length(timesteps)
                tup = (timesteps[i], mps[i],)
                push!(ts.series, tup)
            end
            push!(markets[mm.market].price, ts)
            append!(dates, timesteps)
        end
    end
    return (unique(dates), scenarios, nodes, processes, markets)
end
#=

function import_node(node_data)
    #Create node object
end

function import_process(process_data)
    #create process_objhect
end

function create_reserves(nodes, processes, reserves, everything_which_is_needed)
    #for n in nodes
    # if n.is_res:
    # create n_res node/find the linked reserve
    # connect n_res with each process which is_res
    # v_flow["process"_res_up, "process", n-res] and v_flow["process"_res_down, "process", n-res]
    # Check the type of reserve fast/slow?
    # in case of slower reserves(?) set the bounds as (v_flow[process, process, elc] +/- ramp)
    # for producers or alternatively (v_flow[process, elc, process] +/- ramp) for consumers
    # set the bounds as GenericConstraints
    # For fast reserves, 
end

function initialize_states()
    # create new storage nodes for nodes_with state
    # create node with state, remove state from old node
    # create transfer processes between node and storage node
end

function create_generic_constraint()
    # called by other functions or based on input data
    # generate generic_constraint, which is fed to model. 
    return 0
end
=#