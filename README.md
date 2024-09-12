# acme-ca-smallstep

Pull the image, tag & push to local registry.

Get the step-cli installed locally:
  wget https://dl.smallstep.com/cli/docs-cli-install/latest/step-cli_amd64.deb
  sudo dpkg -i step-cli_amd64.deb

Then you can get the fingerprint

{
  CA_FINGERPRINT=$(docker run -v /work/pschneider/acme-ca-smallstep/test.ca.acme.local:/home/step docker01mxlinux.acme.local:5000/smallstep/step-ca:0.27.2 step certificate fingerprint certs/root_ca.crt)
  step ca bootstrap --ca-url https://docker01mxlinux.acme.local:9000 --fingerprint $CA_FINGERPRINT --install
}

then create a cert

step ca certificate --ca-url https://docker01mxlinux.acme.local:9000 --san localhost --san 10.5.1.143 --san admin01mxlinux admin01mxlinux.acme.local admin01mxlinux.acme.local.crt admin01mxlinux.acme.local.key

step certificate inspect client-portal01.cloud.quolab.com.crt


