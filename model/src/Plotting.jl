using Plots
using DataFrames

function PlotUnitReserve(t,y_flow,y_up,y_down,y_max,y_min)
    fig_size_x = 1000
    fig_size_y = 300
    max_cap = y_max .*ones(size(temporals))
    min_cap = y_min .*ones(size(temporals))
    res_up = y_flow .+y_up
    res_dn = y_flow .-y_down
    plot(t,min_cap,fillrange=max_cap,fillalpha=0.25,fillcolor=:lightskyblue,size=(fig_size_x,fig_size_y),label="")

    plot!(t,min_cap,linestyle=:dash,linecolor=:deepskyblue,label="")
    plot!(t,max_cap,linestyle=:dash,linecolor=:deepskyblue,label="")
    
    plot!(t,res_up,linestyle=:dashdot,lw=2,linecolor=:mediumseagreen,label="Reserve-up")
    plot!(t,res_dn,linestyle=:dashdot,lw=2,linecolor=:coral3,label="Reserve-down")
    plot!(t,y_flow,lw=2,label="Generation",linecolor=:darksalmon)
end
