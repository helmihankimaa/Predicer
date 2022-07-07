using Predicer

input_data = import_input_data("input_data.xlsx")

model_contents = Initialize(input_data)

solve_model(model_contents)