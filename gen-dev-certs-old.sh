#!/bin/bash

export ID_CPQ=client-portal-quolab
step ca certificate --ca-url https://localhost:9000 --san localhost --san ${ID_CPQ} ${ID_CPQ} ${ID_CPQ}.crt ${ID_CPQ}.key

export ID_CPS=client-portal-server
step ca certificate --ca-url https://localhost:9000 --san localhost --san ${ID_CPS} ${ID_CPS} ${ID_CPS}.crt ${ID_CPS}.key

export ID_CPU=client-portal-ui
step ca certificate --ca-url https://localhost:9000 --san localhost --san ${ID_CPU} ${ID_CPU} ${ID_CPU}.crt ${ID_CPU}.key

export ID_P1=client-portal01.cloud.quolab.com
export ID_A1=app01.client-portal01.quo.lab
step ca certificate --ca-url https://localhost:9000 --san localhost --san ${ID_P1} --san ${ID_A1} ${ID_P1} ${ID_P1}.crt ${ID_P1}.key

export ID_P2=client-portal02.cloud.quolab.com
export ID_A2=app01.client-portal02.quo.lab
step ca certificate --ca-url https://localhost:9000 --san localhost --san ${ID_P2} --san ${ID_A2} ${ID_P2} ${ID_P2}.crt ${ID_P2}.key
