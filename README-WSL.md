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
    git clone --recurse-submodules https://github.com/Accelergy-Project/accelergy-timeloop-infrastructure.git
    cd accelergy-timeloop-infrastructure

    cd src/cacti ; make ; cd ..
    cd accelergy-neurosim-plug-in ; make ; cd ..
    pip3 install ./accelergy
    pip3 install ./accelergy-aladdin-plug-in
    pip3 install ./accelergy-cacti-plug-in
    pip3 install ./accelergy-table-based-plug-ins
    pip3 install ./accelergy-neurosim-plug-in
    pip3 install ./accelergy-library-plug-in
    pip3 install ./accelergy-adc-plug-in
    cp -r ./cacti ~/.local/share/accelergy/estimation_plug_ins/accelergy-cacti-plug-in/

    cd timeloop
    ln -s "$(pwd)/pat-public/src/pat" ./src
    scons --accelergy --static -j 16
    cp build/timeloop-* ~/.local/bin
```

Running locally

```
    export PATH=~/.local/bin:$PATH
    cd src/timeloop-accelergy-exercises/exercise
```
