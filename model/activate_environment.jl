using Pkg
function main(aa)
    Pkg.activate(@__DIR__)
    print(Pkg.status())
    #include(args[1])
    plot(([1:5], [5:1]))
end
