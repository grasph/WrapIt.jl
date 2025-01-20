"""
   WrapIt

Module to install the [WrapIt!](https://www.github.com/grasph/wrapit) tool. It also provides a function to run the tool from the Julia REPL.

See [`WrapIt.install`](@ref) to run the tool ouside of Julia, and [`wrapit`](@ref) to run it from the Julia REPL.

"""
module WrapIt

export wrapit, wrapit_path

import WrapIt_jll
import Base.Filesystem.samefile #required for Julia versions < 1.9

function __init__()
    if Sys.iswindows()
        error("The $(@__MODULE__) package cannot be used on Windows operating systems.")
    end
end


function _library_path_varname()
    if Sys.islinux()
        return "LD_LIBRARY_PATH"
    elseif Sys.isapple()
        return "DYLD_LIBRARY_PATH"
    else
        error("The platform is not supported.")
    end
end

function _library_path_value()
    paths = [ joinpath(WrapIt_jll.artifact_dir, "lib"); # required to get llvm and clang shipped with wrapit taking precedence on once from Julia installation
              WrapIt_jll.LIBPATH_list...; #libcrypto from OpenSSL
              joinpath(dirname(Sys.BINDIR), "lib"); joinpath(dirname(Sys.BINDIR), "lib", "julia") #c++ std lib from Julia installation
            ]
    join(paths, ":")
end

"""
  wrapit_path

Path to the wrapit executable as installed by the package manager. Use the [`Wrapit.install()`](@ref) function to install a shortcut in a more convenient directory e.g. a directory included in the shell executable search PATH.
"""
wrapit_path = WrapIt_jll.wrapit_path

"""
   WrapIt.install(path=".")

Install the [wrapit](https://www.github.com/grasph/wrapit) command to be run outside of Julia.

More precisely, it creates a symbolic file link to the already installed wrapit binaries in the current directory or the directory under `path` . The binaries themselves are installed by the Julia package manager when adding the WrapIt module.

See also [`wrapit`(@ref)].
"""
function install(path=".")
    if !isdir(path)
        println(stderr, "The path ", path, " is not a directory. Installation failed.")
        return 1
    end

    if !isfile(wrapit_path)
        println(stderr, "WrapIt executable not found. Check that WrapIt package installed and run 'import Pkg; Pkg.instantiate()'. Installation failed.")
        return 1
    end

    destpath = joinpath(path, "wrapit")
    destdir = dirname(destpath)
    destdir_h = (destdir == "." ? "current" : destdir) * " directory"

    if samefile(destpath, wrapit_path)
        println("The wrapit command is already installed in ", destdir_h, ".")
        return 0
    end

    if isfile(destpath)
        println(stderr, "File ", destpath , " is on the way. You need to remove it before running install.")
        return 1
    end


    julialib = joinpath(dirname(Sys.BINDIR), "lib")
    
    try
        if Sys.isapple()
            set_sdkroot_code = raw"""

if [ -z "$SKDROOT" ]; then
    export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
    [ $? = 0 ] || { echo "Failed to set SDKROOT environment variable. Please ensure XCode is installed and xcrun is available" 1>&2; exit 1; }
    [ -d "$SDKROOT" ] || { echo "Directory '$SDKROOT' returned by the 'xcrun --sdk macosx --show-sdk-path' command was not found." 1>&2; exit 1;}
else
    [ -d "$SDKROOT" ] || { echo "Directory '$SDKROOT' set in the SDKROOT environment variable was not found." 1>&2; exit 1;}
fi
"""
        else
            set_sdkroot_code = ""
        end
        open(destpath, "w") do f
            print(f, """
#!/bin/sh

exe="$wrapit_path"
[ -f "\$exe" ] || { echo "Error. The wrapit binary file was not found, please reinstall it from Julia (import WrapIt; WrapIt.install())." 1>&2; exit 1; }

""",
                  set_sdkroot_code,
                  """
export $(_library_path_varname())="$(_library_path_value())"

exec "\$exe" "\$@"
""")
        end

        #made the file executable:
        chmod(destpath, stat(destpath).mode | 0o111)
        
        println("Command wrapit installed in ", destdir_h, ". Run ", destpath, " --help to get help on the command invocation.")

    catch e
        showerror(stderr, e)
        println(stderr, ". Installation failed.")
    end

    return 0
end

"""
   wrapit(;`args`)

Launch the [wrapit](https://www.github.com/grasph/wrapit) command. The command options are passed as function arguments in the form of:
 * <option name>=<option value> for options that takes an argument. E.g., `resource_dir=/usr/lib/...` to pass `--resource-dir=/usr/lib...` option.
 * <option name>=true for options with no argument. E.g., `force=true` to pass the `--force` option.

Underscores are used in the argument name in place of dashs used in the option name.

Call `wrapit(help=true)` to get the list of options.

If `returncode = true` is passed as argument, the function returns the exit code of the `wrapit` command (0 in case of success) and `nothing` otherwise.
"""
function wrapit(args...; kwargs...)::Union{Int, Nothing}
    cmd_args = [WrapIt.wrapit_path]

    returncode = false
    for (k, v) in kwargs
        if k == :returncode
            returncode = convert(Bool, v)
            continue
        end
        k = replace(string(k), "_" => "-")
        cmd_opt = (length(k) == 1 ? "-" : "--") * k
        if isa(v, Bool)
            v && push!(cmd_args, cmd_opt)
        else
            push!(cmd_args, cmd_opt * "=" * string(v))
        end
    end

    append!(cmd_args, args)

    env = copy(ENV)
    varname = _library_path_varname()
    env[varname] = _library_path_value()

    if haskey(ENV, varname)
        env[varname] *= ":" * ENV[varname]
    end

    if Sys.isapple()
        if haskey(env, "SDKROOT")
            sdkroot = env["SDKROOT"]
            isdir(sdkroot) || error("Directory '$sdroot' set by SDKROOT environment variable was not found")
        else
            try
                env["SDKROOT"] = readchomp(`xcrun --sdk macosx --show-sdk-path`)
                sdkroot = env["SDKROOT"]
                isdir(sdkroot) || error("Directory returned by 'xcrun --sdk macosx --show-sdk-path' command was not found.")
            catch
                error("Failed to run the command 'xcrun --sdk macosx --show-sdk-path'. Please check XCode is installed on your system.")
            end
        end
    end
    
    p =  run(Cmd(Cmd(cmd_args), env=env, ignorestatus=true))

    if returncode
        if p.termsignal > 0
            #if killed, we expect 128 + signal #, while p.exitcode is 0
            exitcode = 128 + p.termsignal
        else
            exitcode = p.exitcode
        end
        return exitcode
    else
        return nothing
    end
    nothing
end

end # module Wrapit
