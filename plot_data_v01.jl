"""
Download seismic data from server
May 23, 2019
Kurama Okubo
"""

using SeisIO, Printf, PlotlyJS, JLD2, FileIO

finame = "./data/SeisData_BP.jld2"
sr = 10 #downsampling for plotting
netstaID = 1 #to choose station
channelID = 1 #to choose station
#----------------#

# load data
@load finame S

#plotting
layout = Layout(width=1200, height=800, xaxis_range = [0, 60],
				yaxis_range = [-1, 25],
				xaxis=attr(title="Time [min]", dtick=10.0),
				yaxis=attr(title="Hours"),
                font =attr(size=18),
                showlegend=true,
                title =  S[1][netstaID][plotnscID].id)
p = plot([NaN], layout)

for stid = 1:size(S,1)

    requeststr = S[stid][netstaID][plotnscID].id
    sttime = u2d(S[stid][netstaID][plotnscID].t[1,2]*1e-6)

	println("test1")
    dt = 1.0./S[stid][netstaID][plotnscID].fs[1]
    t = LinRange(0.0:dt[1]:(S[stid][netstaID][plotnscID].t[2]-1)*dt[1])
    pt = t[1:sr:end]./60 # plot in [min]
	println("test2")

    #arbitrary amplitude normalization for plotting
    normalized_amp=2.0*maximum(abs.(S[1][netstaID][plotnscID].x))
	if maximum(abs.(S[stid][netstaID][plotnscID].x)) > 2.0*normalized_amp
		normalized_amp=0.2*maximum(abs.(S[stid][netstaID][plotnscID].x))
	end
	println("test3")

    trace1 = scatter(;x=pt, y= S[stid][netstaID][plotnscID].x[1:sr:end]./normalized_amp .+ (stid-1.0), mode="lines", line=attr(dash = false),
    name=@sprintf("%s: %s", requeststr, string(sttime)))
	println("test4")

    addtraces!(p, trace1)
end
deletetraces!(p, 1)
