# powerai-container-xfce

Docker image to provide VNC interface to access Ubuntu 16.04 xfce4 desktop environment with PowerAI 4.0.
This image leverage S6 to supervise entire processes in the container.

Quick Start
-------------------------
Build the docker image.

```
sudo docker build -t <DOCKERHUB_ID>/<REPOSITORY_NAME>:<TAG_NAME> .
```

Run the docker image with nvidia-docker command.  

```
sudo NV_GPU=0 nvidia-docker run --net=<NETWORK> --ip=<IP> -d --name <CONTAINER_NAME> <DOCKERHUB_ID>/<REPOSITORY_NAME>:<TAG_NAME>
```
Now, open the vnc viewer and connect to port 5901.


<img src="https://raw.github.com/koheinomura/powerai-container-xfce/master/screenshots/xfce.png?v1" width=600/>
