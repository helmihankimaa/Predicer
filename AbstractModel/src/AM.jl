#using SpineInterface
using JuMP
using Cbc
using DataFrames
using StatsPlots
using Plots
using TimeZones

# Basic settings
function Initialize()
    model = JuMP.Model(Cbc.Optimizer)
    set_optimizer_attributes(model, "LogLevel" => 1, "PrimalTolerance" => 1e-7)
    return model
end

# Add all constraints, (expressions? and variables?) into a large dictionary for easier access, and being able to use the anonymous notation
# while still being conveniently accessible. 
function Initialize_contents()
    model_contents = Dict()
    model_contents["c"] = Dict() #constraints
    model_contents["c"]["gcs"] = Dict() #GenericConstraints
    model_contents["e"] = Dict() #expressions?
    model_contents["v"] = Dict() #variables?
    model_contents["t"] = Dict() #tuples used by variables?
    model_contents["t"]["p"] = Dict() #process name as keys
    model_contents["t"]["n"] = Dict() #node name as keys
    return model_contents
end

function read_GenExpr(ge::GenExpr)
    # Reads a GenExpr, and returns the value
    if ge.c_type == AbstractExpr
        c_coeff = read_GenExpr(ge.coeff) #Returns value of nested GenExpr
    elseif ge.c_type <: Real
        c_coeff = ge.coeff
    end
    if ge.e_type == AbstractExpr
        return ge.c_coeff.* read_GenExpr(ge.entity)
    elseif ge.e_type == Process # do different things depending on the datatype of the GenExpr
        pname = ge.entity.name
        tup = model_contents["t"][pname] # This could return all variables associated with the process
        if ge.time_specific
            return c_coeff .* v_flow[filter(t -> t[4] == ge.timestep, tup)]
        else
            return c_coeff .* v_flow[tup]
        end
    elseif ge.e_type == TimeSeries
        if ge.time_specific
            return c_coeff * filter(t -> t[1] == ge.timestep, ge.entity.series)[1][2]
        elseif !ge.time_specific
            return c_coeff .* map(t -> t[2], ge.entity.series)
        end
    elseif ge.e_type <: Real
        return ge.coeff * ge.entity
    end
end

function set_gc(gc)
    if !(length(gc.left_f) - length(gc.left_op) == 1)
        return error("Invalid general constraint parameters. Lefthandside invalid")
    elseif !(length(gc.right_f) - length(gc.right_op) == 1)
        return error("Invalid general constraint parameters. Righthandside invalid")
    end
    # Build lefthand side of constraint
    left_expr = @expression(model, read_GenExpr(gc.left_f[1]))
    if length(gc.left_f) > 1
        for ge_i in 2:length(gc.left_expr)
            left_expr = eval(Meta.parse(gc.left_op[i-1]))(left_expr, read_GenExpr(gc.left_f[i]))
        end
    end
    right_expr = @expression(model, read_GenExpr(gc.right_f[1]))
    if length(gc.right_f) > 1
        for ge_i in 2:length(gc.right_expr)
            right_expr = eval(Meta.parse(gc.right_op[i-1]))(right_expr, read_GenExpr(gc.right_f[i]))
        end
    end
    if gc.symbol == ">="
        model_contents["c"]["gcs"][gc.name] = @constraint(model, left_expr .>= right_expr)
    elseif gc.symbol == "=="
        model_contents["c"]["gcs"][gc.name] = @constraint(model, left_expr .== right_expr)
    elseif gc.symbol == "<="
        model_contents["c"]["gcs"][gc.name] = @constraint(model, left_expr .<= right_expr)
    end
end

function set_generic_constraints(gcs)
    for gc in gcs
        set_gc(gc)
    end
end



#=
Only linear allowed!
x*y>0 not allowed
x + y >0 allowed
Each expression can be divided into 
ax * by ..... + c >= 0, where operator varies
a, b, c are scalars, while x and y can be something else.
x and y must have same dimensions
x * y can be allowed, if y is a scalar, such as the value of a TimeSeries at time t

In: GenericConstraint consisting of GenExpr's and functions to combine these.
Use eval(Meta.parse("function name such as + or min"))

Endgame: combine small GenExpr-expressions such as 2 * v_flow[, , , t]  and 1 * v_flow[, , , t-1]
Combine using eval(Meta.parse(function_name_as_string))(expr1, expr2)
How to manage timesteps? Use 'time_specific' flag, and return whole timeseries if false, and 
for one t if true. 


Must be same dimensions
Then @constraint(model, @expr_left "operator" @expr_right)
These are constructed of GenExpr structs containing the datatype, entity, coefficent and time lag of an expr
Each given entity links to a Node(?) Process or TimeSeries, or they can be a Real number (+c a few rows up)

The GenericConstraints need to be able to create the following constraints:
min(a, b)
max(a,b)
a>b
a[t] - a[t-n] >0
min(a[t], a[t-n])
min(a[t_n], a[t_m])


=#