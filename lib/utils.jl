module Utils
export get_starttimelist, initlogo, save_SeisData2JLD2
using Dates, JLD2, FileIO, SeisIO
"""
get_starttimelist(st::DateTime, et::DateTime, unittime::Float64)
calculate start time list for parallel downloading

    st: start time
    et: end time
    unittime: unit time in Second

    this function returns
    stlist: list of start time

    e.g.
    st = DateTime(2019,1,1,0,0,0)
    et = DateTime(2019,1,1,12,0,0)
    unittime = 3600

    stlist = get_starttimelist(st, et, unittime)

"""
function get_starttimelist(st::DateTime, et::DateTime, unittime::Real)

    reftime = st
    stlist = []

    while reftime <= et
        push!(stlist, string(reftime))
        reftime += Dates.Second(float(unittime))
    end

    return stlist
end


"""
save_SeisData2JLD2(foname::String, groupname::String, S::SeisData)
save SeisData structure to JLD2
"""
function save_SeisData2JLD2(foname::String, varname::String, S::SeisData)

    file = jldopen(foname*".jld2", "r+")
    file[varname] = S[1]
    JLD2.close(file)

    return nothing
end



"""
initlogo()
print initial logo
"""
function initlogo()

    print("

      _____        _       _____                          _                    _
     / ____|      (_)     |  __ \\                        | |                  | |
    | (___    ___  _  ___ | |  | |  ___ __      __ _ __  | |  ___    __ _   __| |
     \\___ \\  / _ \\| |/ __|| |  | | / _ \\\\ \\ /\\ / /| '_ \\ | | / _ \\  / _` | / _` |
     ____) ||  __/| |\\__ \\| |__| || (_) |\\ V  V / | | | || || (_) || (_| || (_| |
    |_____/  \\___||_||___/|_____/  \\___/  \\_/\\_/  |_| |_||_| \\___/  \\__,_| \\__,_|
                      _         _  _
                     | |       | |(_)           |
    __      __       | | _   _ | | _   __ _     | v1.0.0 (Last update 05/21/2019)
    \\ \\ /\\ / /   _   | || | | || || | / _` |    | © Kurama Okubo
     \\ V  V /_  | |__| || |_| || || || (_| |    |
      \\_/\\_/(_)  \\____/  \\__,_||_||_| \\__,_|    |

")

    println("Job start running at "*string(now())*"\n")

end


end
