# CACTI Plug-in for Accelergy

An energy estimation plug-in for [Accelergy framework](https://github.com/nelliewu95/accelergy)

## Get started 
- Install [Accelergy framework](https://github.com/nelliewu95/accelergy)
- Download and build [CACTI7](https://github.com/HewlettPackard/cacti) 

## Use the plug-in
- Clone the repo by ```git clone https://github.com/nelliewu95/accelergy-cacti-plug-in.git```
- Place the built CACTI7 
    - Inside the cloned folder (or a subfolder inside the cloned folder)
    - Inside any folder (or its subfolder) that is included in the ```$PATH```
- Option 1
    - Run ```pip3 install .``` and use the same arguments as installing Accelergy 
- Option 2
    - Open Accelergy's config file ```accelergy_config.yaml``` and add a new list item that points to the cloned folder
- To set the relative accuracy of your CACTI plug-in
    - open ```cacti_wrapper.py``` 
    - Edit the first line to set the ```CACTI_ACCURACY``` (default is 70)
- Run Accelergy (Accelergy's log will show that it identifies the CACTI plug-in )
