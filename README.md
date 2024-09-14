# my-ca-smallstep

## Background

For may reasons, it can be useful to have your own private Certificate Authority.

I mostly use it for development testing to verify new components I create work with TLS1.2 connections. You create a root cert you can distribute in your test environment, and create/use client certs t are validated against it. 

There's various toolsets to do it with, but smallstep's docker image is pretty simple and fleixble to use.

More detailed usage notes to follow.


## Installation

Pull the image, tag & push to local registry.

Get the step-cli installed locally:
  wget https://dl.smallstep.com/cli/docs-cli-install/latest/step-cli_amd64.deb
  sudo dpkg -i step-cli_amd64.deb

Then you can get the fingerprint

{
  CA_FINGERPRINT=$(docker run -v /work/pschneider/acme-ca-smallstep/test.ca.acme.local:/home/step example02mxlinux.acme.local:5000/smallstep/step-ca:0.27.2 step certificate fingerprint certs/root_ca.crt)
  step ca bootstrap --ca-url https://example02mxlinux.acme.local:9000 --fingerprint $CA_FINGERPRINT --install
}

then create a cert

step ca certificate --ca-url https://example02mxlinux.acme.local:9000 --san localhost --san 10.5.1.143 --san example01mxlinux example01mxlinux.acme.local example01mxlinux.acme.local.crt example01mxlinux.acme.local.key

step certificate inspect gummybear.cloud.example.com.crt


