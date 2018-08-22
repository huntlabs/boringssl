module deimos.openssl.pool;

import deimos.openssl.crypto;
import deimos.openssl.safestack;
import deimos.openssl.thread;

import core.stdc.stdint;

// Buffers and buffer pools.
//
// |CRYPTO_BUFFER|s are simply reference-counted blobs. A |CRYPTO_BUFFER_POOL|
// is an intern table for |CRYPTO_BUFFER|s. This allows for a single copy of a
// given blob to be kept in memory and referenced from multiple places.

extern (C):
nothrow:

// TODO: Tasks pending completion -@zxp at 8/9/2018, 5:54:46 PM
// 
// mixin DEFINE_STACK_OF!(CRYPTO_BUFFER, "CRYPTO_BUFFER");

// CRYPTO_BUFFER_POOL_free frees |pool|, which must be empty.
void CRYPTO_BUFFER_POOL_free(CRYPTO_BUFFER_POOL *pool);

// CRYPTO_BUFFER_new returns a |CRYPTO_BUFFER| containing a copy of |data|, or
// else NULL on error. If |pool| is not NULL then the returned value may be a
// reference to a previously existing |CRYPTO_BUFFER| that contained the same
// data. Otherwise, the returned, fresh |CRYPTO_BUFFER| will be added to the
// pool.
CRYPTO_BUFFER *CRYPTO_BUFFER_new(const(uint8_t) *data, size_t len,
                                                CRYPTO_BUFFER_POOL *pool);

// CRYPTO_BUFFER_len returns the length, in bytes, of the data contained in
// |buf|.
size_t CRYPTO_BUFFER_len(const(CRYPTO_BUFFER) *buf);

// CRYPTO_BUFFER_data returns a pointer to the data contained in |buf|.
uint8_t *CRYPTO_BUFFER_data(const(CRYPTO_BUFFER) *buf);