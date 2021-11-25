using DataFrames
using XLSX

function import_input_data()
    sheetnames = ["nodes", "processes", "process_topology", "cf", "inflow", "price", "markets", "market_prices"]#, "energy_market", "reserve_market"]

    # Assuming this file is under \predicer\model
    wd = split(string(@__DIR__), "model")[1]
    input_data_path = wd * "input_data\\input_data_V3.xlsx"

    input_data = Dict()

    for sn in sheetnames
        input_data[sn] = DataFrame(XLSX.readtable(input_data_path, sn)...)
    end

    dates = []

    nodes = Dict()
    for i = 1:nrow(input_data["nodes"])
        n = input_data["nodes"][i, :]
        nodes[n.node] = Node(n.node, Bool(n.is_commodity), Bool(n.is_state), Bool(n.is_res), Bool(n.is_inflow), Bool(n.is_market), n.state_max, n.in_max, n.out_max)
        if Bool(n.is_commodity)
            ts = input_data["price"].t
            ps = input_data["price"][!, n.node]
            for i = 1:length(ts)
                tup = (ts[i], ps[i],)
                push!(nodes[n.node].cost, tup)
            end
            append!(dates, input_data["price"].t)
        end
        if Bool(n.is_inflow)
            ts = input_data["inflow"].t
            f = input_data["inflow"][!, n.node]
            for i = 1:length(ts)
                tup = (ts[i], f[i],)
                push!(nodes[n.node].inflow, tup)
            end
            append!(dates, input_data["inflow"].t)
        end
    end

    processes = Dict()
    for i = 1:nrow(input_data["processes"])
        p = input_data["processes"][i, :]
        processes[p.process] = Process(p.process, Bool(p.is_cf), Bool(p.is_online), Bool(p.is_res), string(p.conversion), p.eff, p.load_min, p.load_max, p.ramp_up, p.ramp_down)
        if Bool(p.is_cf)
            ts = input_data["cf"].t
            cf = input_data["cf"][!, p.process]
            for i = 1:length(ts)
                tup = (ts[i], cf[i],)
                push!(processes[p.process].cf, tup)
            end
            append!(dates, input_data["cf"].t)
        end
        sources = []
        sinks = []
        for j = 1:nrow(input_data["process_topology"])
            pt = input_data["process_topology"][j, :]
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
                push!(processes[p.process].topos, (so[1], p.process, so[2], so[3]))
            end
            for si in sinks
                push!(processes[p.process].topos, (p.process, si[1], si[2], si[3]))
            end
        elseif p.conversion == 2
            for so in sources, si in sinks
                push!(processes[p.process].topos, (so[1], si[1], min(so[2], si[2]), so[3]))
            end
        elseif p.conversion == 3
            for so in sources, si in sinks
                push!(processes[p.process].topos, (so[1], si[1], min(so[2], si[2]), so[3]))
                push!(processes[p.process].topos, (si[1], so[1], min(so[2], si[2]), si[3]))
            end
        end
    end

    markets = Dict()
    for i = 1:nrow(input_data["markets"])
        mm = input_data["markets"][i, :]
        markets[mm.market] = Market(mm.market, mm.type, mm.node, mm.direction)
        ts = input_data["market_prices"].t
        mp = input_data["market_prices"][!, mm.market]
        for i = 1:length(ts)
            tup = (ts[i], mp[i],)
            push!(markets[mm.market].price, tup)
        end
        append!(dates, input_data["market_prices"].t)
    end

    return (unique(dates), nodes, processes, markets)
end