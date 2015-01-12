## Nonogram solver: our university project this semester in Programming 2.

Licensed under the CreativeCommons Attribution-NonCommercial-NoDerivatives 4.0 International License.

(This was our homework; published for educational purposes only; please don't
rip it off and hand it in as if it was your own homework.)

# Authors:

- Arpad Goretity ([@H2CO3_iOS](http://twitter.com/H2CO3_iOS))
- Olivia Kozak
- Reka Toth

# Building and running

Compiling requires Gecode, the open constraints programming library.
Written in a cursed mixture of C++ and Objective-C++; only tested on OS X 10.9.5 Mavericks.

Compile using `make`. Run by typing `make run` or by opening the included app bundle,
`NonogramSolver.app`.

The GUI is in English and the menu item titles are quite self-explanatory;
if something doesn't work for you, please let me know.
In addition, if you know Hungarian, you can read `usage.rtf`.

You can find example puzzles and solutions in the `examples/` directory.
Files with the extension `.constraint` are puzzles in a particular format
(which is pretty trivial to guess), whereas `.table` files are actual
"image" (rather, table configuration) files, again, in a self-explanatory format.
You can load these kind of files in the program via the "Open..." menu.

Enjoy,
Team "P =?= NP"
