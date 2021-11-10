struct NodeGroup
    name::String
    nodes::Vector{String}
end


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

struct ProcessGroup # Struct to contain separate, but obviously linked processes, such as separate flows in a CHP unit
    name::String
    processes::Vector{String}
    function ProcessGroup(name)
        return new(name, [])
    end
end

struct Process
    name::String
    # group::String
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

# Not implemented
# used to constrain a process to something else, such as t, another process, or anything else. 
# Could be used to implement ramp rates? 
#struct GenericConstraint
#    type::String # Type of constraint: CHP processes? Timesteps? Anything else? 
#    p1::Any # The first thing being constrained. This could be a process,  
#    p2::Any # The second thing being constrained.
#    function GenericConstraint
#        return new()
#    end
#end
