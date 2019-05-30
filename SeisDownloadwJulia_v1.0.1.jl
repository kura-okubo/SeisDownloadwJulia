"""
Download seismic data from server and save to JLD2 file.

May 29, 2019
Kurama Okubo
"""

using SeisIO, Noise, Printf, Dates, PlotlyJS, JLD2, FileIO, MPI, ProgressMeter

# Self-defined functions
include("./lib/utils.jl")
using .Utils

#------------------------------------------------------------------#
#For the time being, we need remove_response function from obspy
#This will be replaced by SeisIO modules in the near future.
#Please activate obspy enviroment before launching Julia.
include("./lib/remove_response_obspy.jl")
using .Remove_response_obspy
#------------------------------------------------------------------#

#---parameters---#
Network     = ["BP"]
Station    = ["LCCB", "MMNB", "VCAB", "CCRB"]
#Station     = ["LCCB", "MMNB"]
Channels   = ["BP1", "BP2", "BP3"]
#Channels    = ["BP1"]
src         = "NCEDC" #Data servise center

Starttime   = DateTime(2004,6,1,0,0,0)
Endtime     = DateTime(2004,6,2,0,0,0)
CC_time_unit = 3600 # minimum time unit for cross-correlation [s]

pre_filt    = (0.001, 0.002, 10.0, 20.0) #prefilter of remove_response: taper between f1 and f2, f3 and f4
downsample_fs = 20; #downsampling rate after filtering
MAXMPINUM   = 32 #Limit np for parallel downloading

IsRemoveStationXML = true #Removing all StationXML. (instrumental response is automatically removed before removing XML)
foname      = "./data/SeisData_BP" #output name
#----------------#

MPI.Init()

# establish the MPI communicator and obtain rank
comm = MPI.COMM_WORLD
size = MPI.Comm_size(comm)
rank = MPI.Comm_rank(comm)

# print initial logo and info
if rank == 0 Utils.initlogo() end

#-------------------------------------------------------------------#
#NEVER CHANGE THIS THRESHOLD OTHERWISE IT OVERLOADS THE DATA SERVER
if size > MAXMPINUM throw(DomainError(size, "np must be smaller than $MAXMPINUM.")) end
#-------------------------------------------------------------------#

# calculate start time with each CC_time_unit
stlist = get_starttimelist(Starttime, Endtime, CC_time_unit)

# save download information in JLD2
if rank == 0
    jldopen(foname*".jld2", "w") do file
        file["info/Network"]     = Network
        file["info/Station"]     = Station
        file["info/Channels"]    = Channels
        file["info/Starttime"]   = string(Starttime)
        file["info/Endtime"]     = string(Endtime)
        file["info/CC_time_unit"]= string(CC_time_unit)
    end
end

mpiitrcount = 0
baton = Array{Int32, 1}([0]) # for Relay Dumping algorithm

# progress bar
if rank == 0 prog = Progress(floor(Int, length(stlist)/size), 1.0) end

for stid = 1:length(stlist) #to be parallelized
    processID = stid - (size * mpiitrcount)

    # if this mpiitrcount is final round or not
    length(stlist) - size >= size * mpiitrcount ? anchor_rank = size-1 : anchor_rank = mod(length(stlist), size)-1

    if rank == processID-1

        for networkid = 1:length(Network)

        	for stationid = 1:length(Station)

                for channelsid = 1:length(Channels)

                    requeststr = @sprintf("%s.%s..%s", Network[networkid], Station[stationid], Channels[channelsid])

                    #---download data---#
                    S = get_data("NCEDC", requeststr, s=stlist[stid],t=CC_time_unit, v=0, src=src, w=false, xf="$requeststr.$stid.xml")

                    #---remove response---#
                    Remove_response_obspy.remove_response_obspy!(S, "$requeststr.$stid.xml", pre_filt=pre_filt, output="VEL")
                    if IsRemoveStationXML rm("$requeststr.$stid.xml") end

                    #---check for gaps---#
                    SeisIO.ungap!(S)

                    #---remove earthquakes---#
                    # NOT IMPLEMENTED YET!

                    #---detrend---#
                    SeisIO.detrend!(S)

                    #---bandpass filter---#
                    SeisIO.filtfilt!(S,fl=0.01,fh=0.9*(0.5*S.fs[1])) #0.9*Nyquist frequency

                    #---taper---#
                    SeisIO.taper!(S,t_max=30.0,α=0.05)

                    #---sync starttime---#
                    SeisIO.sync!(S,s=DateTime(stlist[stid]),t=DateTime(stlist[stid])+Dates.Second(CC_time_unit))

                    #---down sampling---#
                    # Note: filtering should be first then down sampling
                    S = Noise.downsample(S, float(downsample_fs))
                    SeisIO.note!(S, "downsample!, downsample_fs=$downsample_fs")

                    #save data to JLD2 file
                    yj = parse(Int64,stlist[stid][1:4])
                    dj = md2j(yj, parse(Int64,stlist[stid][6:7]), parse(Int64,stlist[stid][9:10]))
                    groupname    = string(yj)*"."*string(dj)*"."*stlist[stid][11:19] #Year_Julianday_Starttime
                    varname = groupname*"/"*requeststr

                    # Relay Data Dumping algorithm to aboid writing conflict with MPI
                    if size == 1
                        save_SeisData2JLD2(foname, varname, S)

                    else
                        if rank == 0
                            save_SeisData2JLD2(foname, varname, S)

                            if anchor_rank != 0
                                MPI.Send(baton, rank+1, 11, comm)
                                MPI.Recv!(baton, anchor_rank, 12, comm)
                            end

                        elseif rank == anchor_rank
                            MPI.Recv!(baton, rank-1, 11, comm)
                            save_SeisData2JLD2(foname, varname, S)
                            MPI.Send(baton, 0, 12, comm)

                        else
                            MPI.Recv!(baton, rank-1, 11, comm)
                            save_SeisData2JLD2(foname, varname, S)
                            MPI.Send(baton, rank+1, 11, comm)
                        end
                    end
                end
            end
        end
        #println("stid:$stid done by rank $rank out of $size processors")
        global mpiitrcount += 1

        #progress bar
        if rank == 0 next!(prog) end
    end
end

if rank == 0 println("Downloading and Saving data is successfully done.\njob ended at "*string(now())) end

MPI.Finalize()
