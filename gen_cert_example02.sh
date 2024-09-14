# below -- default duration is one (1) day
# step ca certificate --ca-url https://docker01mxlinux.example.local:9000 --san localhost --san 10.5.1.144 --san docker01mxlinux docker01mxlinux.example.local docker01mxlinux.example.local.crt docker01mxlinux.example.local.key
#
# below -- explicit time params, 720h = 30d
step ca certificate \
  --ca-url https://docker01mxlinux.example.local:9000 \
  --not-before=1m \
  --not-after=240h \
  --san localhost \
  --san 10.5.1.144 \
  --san docker01mxlinux \
  docker01mxlinux.example.local \
  docker01mxlinux.example.local.crt \
  docker01mxlinux.example.local.key 

