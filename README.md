# cyto.nvim
nvim plugin which allows for interactive, cell programming in regular source files.

Requires tmux.

Instructions:
from your config, call require('cyto').setup(cell_start_delim, cell_end_delim) in the manner you see fit and store the results into a var.
Setup is a higher order function which returns a table of functions where the start and end delimiters of your cells
are bound (as well as other variables). These functions can then be bound as you wish.

Right now only ipython is supported.

This allows for some interesting things, like having multiple buffers bound to the same ipython instance. Or multiple buffers bound to different ipython instances. Every buffer could have a different set of cell deliminators and/or keybindings if you were really clever.

More Instructions to come.
