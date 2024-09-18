# Features

- sane defaults
- ability to override the most important job resources
- automatic identification of correct jupyter-lab executable
- OSC52 support to place connection string on the clipboard

See `jlab --help` for usage flags.


# Automatic identification of JupyterLab

We search in the following order, stopping as soon as we find JupyterLab:

1. active virtual environment
2. active pixi environment
3. active conda environment

If we still haven't found a jupyter-lab executable, we check current directory
for non active environments located in:

1. ./.env
2. ./venv
3. ./env
4. ./.pixi/envs/dev
5. ./.pixi/envs/develop
6. ./.pixi/envs/default

If we still haven't found Jupyter Lab, repeat this search for the next
directory up, continuing until we hit the base of the current git repo or we
can't go any further.

Finally, if jupyter-lab has still not been found (or you want to choose a
different executable), you can manually specify the path using the `--jupyter`
option.

# Author

Simon Mutch (@smutch)
