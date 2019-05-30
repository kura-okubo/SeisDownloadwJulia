"""
Download seismic data from server

# Seisdata array structure

S[network_id][station_id][cnannel_id] gives a SeisData structure

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
#Station    = ["LCCB", "MMNB", "VCAB", "CCRB"]
Station     = ["LCCB", "MMNB"]
#Channels   = ["BP1", "BP2", "BP3"]
Channels    = ["BP1", "BP2", "BP3"]
src         = "NCEDC" #Data servise center

Starttime   = DateTime(2004,9,28,0,0,0)
Endtime     = DateTime(2004,9,28,24,0,0)
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

S = Array{Any, 1}(undef, length(stlist));

mpiitrcount = 0

# progress bar
if rank == 0 prog = Progress(floor(Int, length(stlist)/size), 1.0) end

for stid = 1:length(stlist) #to be parallelized

    processID = stid - (size * mpiitrcount)

    if rank == processID-1

        S[stid] = Array{SeisData, 1}(undef, length(Station)); #S[timeid][sta,net,cha id]

        for networkid = 1:length(Network)
        	for stationid = 1:length(Station)

                ns_id = (networkid-1)*(length(Station)) + stationid
                S[stid][ns_id] = SeisData(length(Channels)) #S[timeid][sta,netid][cha id]

                for channelsid = 1:length(Channels)

                    requeststr = @sprintf("%s.%s..%s", Network[networkid], Station[stationid], Channels[channelsid])

                    #---download data---#
                    Stemp = get_data("NCEDC", requeststr, s=stlist[stid],t=CC_time_unit, v=0, src=src, w=false, xf="$requeststr.$stid.xml")

                    #---remove response---#
                    Remove_response_obspy.remove_response_obspy!(Stemp, "$requeststr.$stid.xml", pre_filt=pre_filt, output="VEL")
                    if IsRemoveStationXML rm("$requeststr.$stid.xml") end

                    #---check for gaps---#
                    SeisIO.ungap!(Stemp)

                    #---remove earthquakes---#
                    # NOT IMPLEMENTED YET!

                    #---detrend---#
                    SeisIO.detrend!(Stemp)

                    #---bandpass filter---#
                    SeisIO.filtfilt!(Stemp,fl=0.01,fh=0.9*(0.5*Stemp.fs[1])) #0.9*Nyquist frequency

                    #---taper---#
                    SeisIO.taper!(Stemp,t_max=30.0,α=0.05)

                    #---sync starttime---#
                    SeisIO.sync!(Stemp,s=DateTime(stlist[stid]),t=DateTime(stlist[stid])+Dates.Second(CC_time_unit))

                    #---down sampling---#
                    # Note: filtering should be first then down sampling
                    Stemp = Noise.downsample(Stemp, float(downsample_fs))
                    SeisIO.note!(Stemp, "downsample!, downsample_fs=$downsample_fs")

                    #store Stemp to S
                    S[stid][ns_id][channelsid] = Stemp[1]

                end
            end
        end

        #println("stid:$stid done by rank $rank out of $size processors")
        global mpiitrcount += 1

        #progress bar
        if rank == 0 next!(prog) end

    end
end

#save struct
if rank == 0
    @save foname*".jld2" S
    println("Downloading data is successfully done.")
end

MPI.Finalize()
