# accelergy-aladdin-plug-in

An energy estimation plug-in for [Accelergy framework](https://github.com/nelliewu95/accelergy)

## Get started 
- Install [Accelergy framework](https://github.com/nelliewu95/accelergy)

## Use the plug-in
- Clone the repo by ```git clone https://github.com/nelliewu95/accelergy-aladdin-plug-in.git```
- Option 1
    - Run ```pip3 install .``` and use the same arguments as installing Accelergy
- Option 2
    - Open Accelergy's config file ```accelergy_config.yaml``` and add a new list item that points to the cloned folder
- To set the relative accuracy of your Aladdin plug-in
    - open ```aladdin_table.py``` 
    - Edit the first line to set the ```ALADDIN_ACCURACY``` (default is 70)
- Run Accelergy (Accelergy's log will show that it identifies the Aladdin plug-in )
- The 40nm energy data is stored in the ```data``` folder.
- Note that Aladdin tables use the ```latency``` attribute to characterize primitive components and the plug-in assumes a default 5ns latency.
  Users can specify the ```latency``` attribute when defining a primitive component to make better use of the plug-in.
