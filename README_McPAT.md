# McPAT plug-in

For the McPAT plug-in to work with Timeloop, you need to modify two lines in the _src/mcpat/_ submodule:

* Find the file _mcpat.mk_

* Modify the lines 25 and 26 from:

```
CXX = g++ -m32
CC  = gcc -m32
```

to:

```
CXX = g++ -m64
CC  = gcc -m64
```
