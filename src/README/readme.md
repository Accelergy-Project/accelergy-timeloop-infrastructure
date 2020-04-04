## Accelergy-Timeloop Infrastructure
This docker aims to provide an experimental environment for easy plug-and-play of examples that run on the accelergy-timeloop DNN accelerator evaluation infrastructure. 

### System Setup
Inside this docker you can find the source files of all necessary setups:
- accelergy: the energy estimation backend 
- timeloop: the mapping exploration frontend
- accelergy-cacti-plug-in: SRAM estimation plug-in
- accelergy-aladdin-plug-in: 45nm component plug-in
- accelergy-table-based-plug-in: entry point for creating your own table-based plug-ins
They are already built/installed and ready to run!

### How to use the docker
- Check if you can run the necessary commands below, i.e., you should not see `command not found` message
    - accelergy
    - accelergyTables
    - cacti
    - timeloop-mapper
    - timeloop-model
    
- Get some examples running!
    - You can clone example repos that we provide to you to your docker folder (available example repos can be found in the example repo readme)
    - You can create your own models (if you already know the tools)

Note, to skip this intro:
```touch ~/.nointro```