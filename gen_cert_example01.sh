# below -- default duration is one (1) day
# step ca certificate --ca-url https://example02mxlinux.example.local:9000 --san localhost --san 10.5.1.144 --san example02mxlinux \
# example02mxlinux.example.local example02mxlinux.example.local.crt example02mxlinux.example.local.key
#
# below -- explicit time params, 720h = 30d
#step ca certificate \
#  --ca-url https://example02mxlinux.example.local:9000 \
#  --not-before=1m \
#  --not-after=240h \
#  --san localhost \
#  --san 10.5.1.143 \
#  --san example01mxlinux \
#  example01mxlinux.example.local \
#  example01mxlinux.example.local.crt \
#  example01mxlinux.example.local.key 
#
# below -- one month cert
step ca certificate \
  --ca-url https://example02mxlinux.example.local:9000 \
  --not-before=1m \
  --not-after=240h \
  --san localhost \
  --san 10.5.1.143 \
  --san 10.5.1.144 \
  www.cochise.example.local \
  www.cochise.example.local.crt \
  www.cochise.example.local.key 