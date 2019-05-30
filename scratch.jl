foname      = "./data/SeisData_BP" #output name
file = jldopen(foname*".jld2", "r")

Starttime   = DateTime(2004,9,28,0,0,0)

yj = Dates.year(Starttime)
mj = Dates.month(Starttime)
dj = Dates.day(Starttime)
md2j(yj, mj, dj)
