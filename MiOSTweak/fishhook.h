// fishhook.h — MIT License (Facebook, Inc.). Symbol rebinding for Mach-O images.
#ifndef fishhook_h
#define fishhook_h

#include <stddef.h>
#include <stdint.h>
#include <mach-o/loader.h>

#ifdef __cplusplus
extern "C" {
#endif

struct rebinding {
    const char *name;
    void *replacement;
    void **replaced;
};

// Rebind symbols across all current and future images.
int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

// Rebind symbols only in the given image (identified by its mach_header + slide).
int rebind_symbols_image(void *header, intptr_t slide,
                         struct rebinding rebindings[], size_t rebindings_nel);

#ifdef __cplusplus
}
#endif

#endif
