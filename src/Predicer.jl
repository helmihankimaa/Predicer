module Predicer
using AbstractModel

function init_model()
#using AbstractModel

# Import data using descriptive layer translating the input data to an abstract format
imported_data = include(".\\import_input_data.jl")()




model = AbstractModel.Initialize_model(imported_data)




end # module
