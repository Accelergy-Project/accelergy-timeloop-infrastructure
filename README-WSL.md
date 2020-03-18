Installation requirements

```
    apt install python3

    apt install build-essential
    apt install scons

    apt install libncurses-dev
    apt install libgpm-dev
    apt install libconfig++-dev
    apt install libboost-dev
    apt install libboost-iostreams-dev
    apt install libboost-serialization-dev
    apt install libyaml-cpp-dev

```

Build procedure

```
    git clone --recurse-submodules git@github.com:jsemer/timeloop-accelergy-tutorial.git

    cd src/cacti
    make

    cd ../accelergy
    pip3 install .
    cd ../accelergy-aladdin-plug-in/
    pip3 install .
    cd ../accelergy-cacti-plug-in/
    pip3 install .
    cp -r ../cacti ~/.local/share/accelergy/estimation_plug_ins/accelergy-cacti-plug-in/

    cd ../timeloop
    cd src/
    ln -s ../pat-public/src/pat .
    scons --accelergy -j4
    cp build/timeloop-* ~/.local/bin
```

Running locally

```
    export PATH=~/.local/bin:$PATH
    cd src/timeloop-accelergy-exercises/exercise
```
