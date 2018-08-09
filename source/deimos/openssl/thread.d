module deimos.openssl.thread;

import core.stdc.stdint;

version(OPENSSL_NO_THREADS) {
    struct crypto_mutex_st {
        char padding;  // Empty structs have different sizes in C and C++.
    }

    alias CRYPTO_MUTEX = crypto_mutex_st;
}
else version(Windows) {
    // CRYPTO_MUTEX can appear in public header files so we really don't want to
    // pull in windows.h. It's statically asserted that this structure is large
    // enough to contain a Windows SRWLOCK by thread_win.c.
    union crypto_mutex_st {
        void *handle;
    } 
    
    alias CRYPTO_MUTEX = crypto_mutex_st;   
}
else version(OSX)
{
    alias CRYPTO_MUTEX = pthread_rwlock_t ;
}
else
{
    // It is reasonable to include pthread.h on non-Windows systems, however the
    // |pthread_rwlock_t| that we need is hidden under feature flags, and we can't
    // ensure that we'll be able to get it. It's statically asserted that this
    // structure is large enough to contain a |pthread_rwlock_t| by
    // thread_pthread.c.
    union crypto_mutex_st {
        double alignment;
        uint8_t[3*int.sizeof + 5*uint.sizeof + 16 + 8] padding;
    }

    alias CRYPTO_MUTEX = crypto_mutex_st;
}
