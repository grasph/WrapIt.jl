# Julia package to install [WrapIt!](https://github.com/grasph/wrapit)

This package will allow installation of WrapIt software using the Julia Binary package manager. WrapIt is an application written in C++ to automatize Julia bindings for C++ libraries.

The examples are not installed and can be downloaded from the [wrapit repository](https://github.com/grasph/wrapit).

## Usage


Software download is performed through the Julia package manager and its central registry. It is not needed to clone this repository on your computer. The only software needed to start the installation is [Julia](https://julialang.org/downloads/).

Starts a Jula session and execute the following:

```julia
julia> ]
julia> add WrapIt
julia> [backspace]
```

### If you want to launch `wrapit` outside of the Julia REPL, call the `WrapIt.install()` function:
```julia
julia> using WrapIt
julia> WrapIt.install()
```

💡 You can provide the directory where to install the command as parameter to the `install()` function e.g., `Wrapit.install("/usr/local/bin")`. With no argument, it is installed in the current directory.

### If you prefer to lauch `wrapit` from the Julia REPL, use the `wrapit()` function:
```julia
julia> using WrapIt
julia> wrapit("myconfig.wit", force=true)
```

See the function help (`? wrapit`) and run `wrapit(help=true)` to get help on the command usage. Find examples [here](https://github.com/grasph/wrapit/tree/main/examples) and [here](https://github.com/grasph/wrapit/tree/main/test).
