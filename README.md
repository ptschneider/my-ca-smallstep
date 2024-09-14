# my-ca-smallstep

## Background

For may reasons, it can be useful to have your own private Certificate Authority.

I mostly use it for development testing to verify new components I create work with TLS1.2 connections. You create a root cert you can distribute in your test environment, and create/use client certs t are validated against it. 

There's various toolsets to do it with, but smallstep's docker image is pretty simple and fleixble to use.

More detailed usage notes to follow.


## Installation

Pull the image, tag & push to your local registry.

Create a subdirectory for your CA's data. Add a file named 'init.pwd' with the admin password you want for your test CA.

Update the sample docker-compose.yml file (recommend a short name for your container name) and launch, then review the logs to get the fingerprint and verify the password is what you intended.

```
docker-compose up -d
docker-compose logs
```

The _INIT variables only need to be set for the first run.

Remove them from the docker-compose.yml file and delete the init.pwd passowrd file, if you created one.



## Usage

You can install CLI tools locally or run from a running container.

If you want to install locally:

Get the step-cli installed locally:
  wget https://dl.smallstep.com/cli/docs-cli-install/latest/step-cli_amd64.deb
  sudo dpkg -i step-cli_amd64.deb

Alternatively, you can just run the CLI from the container (below assumes your containername is 'cerberus', and provisioner name was 'admin'; updates config to create 1-week certs by default, or longer ones up to 500 days by special request):
```
docker exec -it cerberus step ca help
docker exec -it cerberus step ca provisioner list
docker exec -it cerberus step ca provisioner update admin --x509-default-dur=168h --x509-min-dur=5m --x509-max-dur=12000h
docker exec -it cerberus \
step ca certificate \
  --ca-url https://localhost:9000 \
  --not-before=1m \
  --not-after=240h \
  --san localhost \
  --san 192.168.0.13 \
  donjulio \
  donjulio.crt \
  donjulio.key 

docker exec -it cerberus step certificate inspect donjulio.crt
```




step certificate inspect gummybear.cloud.example.com.crt


