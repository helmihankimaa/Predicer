abstract type AbstractNode end
abstract type AbstractProcess end
abstract type AbstractState end
abstract type AbstractExpr end

struct State <: AbstractState
    in_max::Float64
    out_max::Float64
    max::Float64
    min::Float64
    function State(in_max, out_max, state_max, state_min=0)
        return new(in_max, out_max, state_max, state_min)
    end
end

mutable struct TimeSeries
    scenario::Any
    series::Vector{Tuple{Any, Any}}
    function TimeSeries(scenario="", series=0)
        if series != 0
            return new(scenario, series)
        else
            return new(scenario, [])
        end
    end
end

struct Node <: AbstractNode
    name::String
    is_commodity::Bool
    is_state::Bool
    is_res::Bool
    is_inflow::Bool
    is_market::Bool
    state::AbstractState
    cost::Vector{TimeSeries}
    inflow::Vector{TimeSeries}
    nodegroup::Vector{AbstractNode}
    function Node(name, is_commodity, is_state, is_res, is_inflow, is_market, state_max, in_max, out_max)
        return new(name, is_commodity, is_state, is_res, is_inflow, is_market, State(in_max, out_max, state_max), [], [], [])
    end
end

struct NodeGroup <: AbstractNode
    name::String
    is_res::Bool
    is_commodity::Bool
    nodes::Vector{AbstractNode}
    function NodeGroup(name, is_res, is_commodity)
        return new(name, is_res, [])
    end
end

struct Topology
    source::String
    sink::String
    capacity::Float64
    VOM_cost::Float64
    function Topology(source, sink, capacity, VOM_cost)
        return new(source, sink, capacity, VOM_cost)
    end
end

# A single process in a unit or a unit
struct Process <: AbstractProcess
    name::String
    is_cf::Bool
    is_online::Bool
    is_res::Bool
    eff::Float64
    load_min::Float64
    load_max::Float64
    ramp_down::Float64
    ramp_up::Float64
    topos::Vector{Topology}
    group::Vector{AbstractProcess}
    cf::Vector{TimeSeries}
    function Process(name, is_cf, is_online, is_res, eff, load_min, load_max, ramp_down, ramp_up)
        return new(name, is_cf, is_online, is_res, eff, load_min, load_max, ramp_down, ramp_up, [], [], [])
    end
end

# The "unit", balance could be checked over this process. 
struct ProcessGroup <: AbstractProcess
    name::String
    processes::Vector{AbstractProcess} # Should this be a string, which can be accessed through the dictionary?
    function ProcessGroup(name)
        return new(name)
    end
end

struct Market
    name::String
    type::String
    node::Any
    direction::String
    price::Vector{TimeSeries}
    function Market(name, type, node, direction)
        return new(name, type, node, direction, [])
    end
end


#Define acceptable data types. Will be extended in the future. 
gcu = Union{Process, TimeSeries, Real, AbstractExpr}

struct GenExpr <: AbstractExpr
    e_type::DataType
    entity::gcu
    c_type::DataType
    coeff::Union{Real, AbstractExpr}
    time_specific::Bool
    time_lag::Int
    stochastic::Any
    timestep::Any
    function GenExpr(entity, coeff, time_specific, time_lag=0, stochastic = "", timestep = "")
        return new(typeof(entity), entity, typeof(coeff), coeff, time_specific, time_lag, stochastic, timestep)
    end
end

struct GenericConstraint
    symbol::String
    left_f::Vector{GenExpr}
    left_op::Vector{String}
    right_f::Vector{GenExpr}
    right_op::Vector{String}
    name::String
    function GenericConstraint(symbol, left_f, left_op, right_f, right_op, name = "")
        return new(symbol, left_f, left_op, right_f, right_op, name)
    end
end


struct Reserve
    name::String
end