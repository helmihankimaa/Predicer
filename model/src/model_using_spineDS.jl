using SpineInterface
using JuMP
using Cbc
using Plots
using Dates

function main(input_data_url="")

    t_start = Dates.now()
    print("Building problem\n")

    # Basic settings
    model = JuMP.Model(Cbc.Optimizer)
    set_optimizer_attributes(model, "LogLevel" => 1, "PrimalTolerance" => 1e-7)

    # import input data, assuming file is run from .\model\src, and data is in ..\data\
    if input_data_url == ""
        cwd = split(replace(@__DIR__, "\\"=>"\\"),"Predicer")[1]
        input_data_url = "sqlite:///" * cwd *"Predicer\\input_data\\input_data.sqlite"
    end
    using_spinedb(input_data_url)

    # Dates For indices use 1:n_dates
    dates = map(x -> x[1], collect(price(commodity=commodity(:elec))))
    n_dates = length(dates)

    # Unit states
    @variable(model, unit_states[dates, node(), unit()], Bin, container=DenseAxisArray)

    # units power/production
    @variable(model, unit_powers[dates, node(), unit()], container=DenseAxisArray)


    # Set unit powers to either 0, or between min and max
    for n in node()
        for date in dates, uname in unit()
            if uname in unit_output_node(node=n)
                @constraint(model, unit_powers[date, n, uname] .<= unit_states[date, n, uname] .* capacity(unit=uname) .* max_load(unit=uname))
                @constraint(model, unit_powers[date, n, uname] .>= unit_states[date, n, uname] .* capacity(unit=uname) .* min_load(unit=uname))
            else
                @constraint(model, unit_powers[date, n, uname] .== 0)
            end
        end
    end

    # Dummy power in case demand cannot be met by production units
    @variable(model, dummy_power[dates, node()])
    for date in dates, n in node()
        @constraint(model, dummy_power[date, n] >= 0)
    end

    # General constraints
    # Production should meet demand for nodes with balance..
    for n in node()
        flow_val = flow(node=n)
        balance_val = balance(node=n)
        if typeof(flow_val) != Nothing && balance_val != 0
            flow_val = map(x -> x[2], collect(flow_val))
            for d in 1:n_dates
                @constraint(model, sum(unit_powers[dates[d], n, :]) + dummy_power[dates[d], n] .== -1 .* flow_val[d])
            end
        end
    end


    #for n in node()
    ##    flow_val = flow(node=n)
    #   if typeof(flow_val) != Nothing
    #       flow_val = map(x -> x[2], collect(flow_val))
    #        for d in 1:n_dates
    ##            @constraint(model, sum(unit_powers[dates[d], n, :]) + dummy_power[dates[d], n] .== 2)#flow_val[d])
    #           #@constraint(model, dummy_power[dates[d], :] .== 2)#flow_val[d])
    #       end
    #   end
    #end

    # Resource limitations
    #for n in node()
    #    for d in dates, uname in unit()
    #        resource_type = source(unit=uname)
    #        if typeof(resource_type) != Nothing
    #            resource_eff = 1.0 # May need to implement?
    #            resource_flow = flow(node=node(:resource_type))
    #            resource_flow = map(x -> x[2], collect(resource_flow))
    #            @constraint(model, unit_powers[date, n, uname] .<= resource_flow[d].* resource_eff)
    #        end
    #    end
    #end

    for n in node()
        for d in 1:n_dates, uname in unit()
            resource_type = source(unit=uname)
            if typeof(resource_type) != Nothing
                resource_eff = eff(unit=uname) # May need to implement?
                local resource_flow = flow(node=node(resource_type))
                resource_flow = map(x -> x[2], collect(resource_flow))
                @constraint(model, unit_powers[dates[d], n, uname] .<= resource_flow[d].* resource_eff)
            end
        end
    end

    # CHP constraint
    # Still not implemented

    #VOM_cost = VOM_cost .* unit states?
    @expression(model, vom_costs[d in 1:n_dates, n in node(), uname in unit()], unit_states[dates[d], n, uname] .* VOM_cost(unit=uname))

    # fuel_cost = power ./ eff .* fuel price
    @expression(model, fuel_costs[d in 1:n_dates, n in node(), uname in unit()], unit_powers[dates[d], n, uname] ./ eff(unit = uname) .* map(x -> x[2], collect(price(commodity=commodity_node(node=n)[1])))[d])

    # Dummy power cost
    @expression(model, dummy_cost[d in 1:n_dates, n in node()], dummy_power[dates[d], n] .* 1000000)

    # sell profit
    @expression(model, sell_profit[d in 1:n_dates, n in node(), uname in unit()], unit_powers[dates[d], n, uname] .* map(x -> x[2], collect(price(commodity=commodity_node(node=unit_output_node(unit=uname))[1])))[d])


    #Objective function
    @objective(model, Min, sum(vom_costs) + sum(fuel_costs) + sum(dummy_cost) - sum(sell_profit))

    print("Problem built, solving problem...\n")

    # optimize the model
    optimize!(model)
    
end