# SeisDownloadwJulia
Download Seismic data from server with [SeisIO.jl](https://github.com/jpjones76/SeisIO.jl)

# Usage
`sh run_downloadsctipt.sh -n 1`

# Tips
- It includes [PyCall](https://github.com/JuliaPy/PyCall.jl) and [obspy](https://github.com/obspy/obspy/wiki) to remove instrumental response.
- It cannot run with large number of processors due to overloading.
