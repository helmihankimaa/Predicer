struct Node
    name::String
    is_commodity::Bool
    is_state::Bool
    is_res::Bool
    is_inflow::Bool
    is_market::Bool
    state_max::Float64
    in_max::Float64
    out_max::Float64
    cost::Vector{Tuple{Any, Float64}}
    inflow::Vector{Tuple{Any, Float64}}
    processes::Vector{Any}
    function Node(name, is_commodity, is_state, is_res, is_inflow, is_market, state_max, in_max, out_max)
        return new(name, is_commodity, is_state, is_res, is_inflow, is_market, state_max, in_max, out_max, [], [], [])
    end
end

struct Process
    name::String
    is_cf::Bool
    is_online::Bool
    is_res::Bool
    conversion::String
    eff::Float64
    load_min::Float64
    load_max::Float64
    ramp_down::Float64
    ramp_up::Float64
    topos::Vector{Tuple{Any, Any, Float64, Float64}}
    cf::Vector{Tuple{Any, Float64}}
    function Process(name, is_cf, is_online, is_res, conversion, eff, load_min, load_max, ramp_up, ramp_down)
        return new(name, is_cf, is_online, is_res, conversion, eff, load_min, load_max, ramp_up, ramp_down, [], [])
    end
end

struct Market
    name::String
    type::String
    node::Any
    direction::String
    price::Vector{Tuple{Any, Int64}}
    function Market(name, type, node, direction)
        return new(name, type, node, direction, [])
    end
end


# Should this layer be more generic. Instead of having ramp up/down, have a 
# parameter called "temporal limitations", or smthing. It could be a tuple
# showing the ramp up/down, or whatever the user wants to. 
# Basically limit the number of parameters in the struct, while maintaining the
# possibility to have many parameters as constraints

# Maybe also implement other limiting factors in a flexible way. These factors
# could be min/max load, capacities, connection with other processes, etc. 

# Each potential limiting factor could be a vector of limitations, so that a process could have
# a vector containing both the information for ramp and minimum shtdown/online time under
# temporal limitations

# limitations = [value, constraint operator(<, <=, =, >=, >), limiting factor(process or time rule?)]

# eff could be a separate value found in all 


# Flow min/max value
# dFlow/dt up/down with amount of time as well as size. Two types (ramp, minimum shtdown/online)
# Connection with other processes (CHP)
# Efficiency/losses
# costs
# sources and sinks
# Online/ofline/aintenance limitations