# BoringSSL for D

It's a D binding for BoringSSL.

## Build BoringSSL 

### Ubuntu
```sh
$ make build && cd build
$ cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=1
$ make
$ sudo cp crypto/libcrypto.* ssl/libssl.* /usr/local/lib
$ sudo ldconfig
```

## Thanks
[OpenSSl binding](https://github.com/D-Programming-Deimos/openssl)
[BoringSSL](https://boringssl.googlesource.com/boringssl/)




