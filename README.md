Accelergy-Timeloop Infrastructure
---------------------------------------------------

This docker aims to provide an experimental environment for easy plug-and-play of examples that run on the accelergy-timeloop DNN accelerator evaluation infrastructure. 

Start the container
-----------------

- Put the *docker-compose.yaml* file in an otherwise empty directory
- Cd to the directory containing the file
- Edit USER_UID and USER_GID in the file to the desired owner of your files
- Run the following command:
```
      % docker-compose run --rm infrastructure 
```
- Follow the instructions in the REAME directory to get public examples for this infrastructure


Refresh the container/exercises
----------------------

To update the Docker container run:

```
     % docker-compose pull
````


Build the container
--------------------

```
      % git clone --recurse-submodules https://github.com/nellie95/accelergy-timeloop-infrastucture.git
      % cd accelergy-timeloop-infrastucture
      % make build [BUILD_FLAGS="<Docker build flags, e.g., --no-cache>"]
```
