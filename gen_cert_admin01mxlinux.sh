# below -- default duration is one (1) day
# step ca certificate --ca-url https://docker01mxlinux.acme.local:9000 --san localhost --san 10.5.1.144 --san docker01mxlinux \
# docker01mxlinux.acme.local docker01mxlinux.acme.local.crt docker01mxlinux.acme.local.key
#
# below -- explicit time params, 720h = 30d
#step ca certificate \
#  --ca-url https://docker01mxlinux.acme.local:9000 \
#  --not-before=1m \
#  --not-after=240h \
#  --san localhost \
#  --san 10.5.1.143 \
#  --san admin01mxlinux \
#  admin01mxlinux.acme.local \
#  admin01mxlinux.acme.local.crt \
#  admin01mxlinux.acme.local.key 
#
# below -- one month cert
step ca certificate \
  --ca-url https://docker01mxlinux.acme.local:9000 \
  --not-before=1m \
  --not-after=240h \
  --san localhost \
  --san 10.5.1.143 \
  --san 10.5.1.144 \
  www.cochise.acme.local \
  www.cochise.acme.local.crt \
  www.cochise.acme.local.key 
