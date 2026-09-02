/*******************************************************************************
 * Copyright (c) 2026 Contributors to the Eclipse Foundation
 *
 * See the NOTICE file(s) distributed with this work for additional
 * information regarding copyright ownership.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Apache License Version 2.0 which is available at
 * https://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0
 ******************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <zlib.h>

int main(void)
{
    static const Bytef data[] =
        "AutoSD dependencies with zlib! "
        "AutoSD dependencies with zlib! "
        "AutoSD dependencies with zlib!";
    /* Compress the text without its terminating NUL byte. */
    const uLong data_size = sizeof(data) - 1;
    uLongf compressed_size = compressBound(data_size);
    Bytef *compressed = malloc(compressed_size);
    if (compressed == NULL) {
        fprintf(stderr, "Failed to allocate compression buffer\n");
        return EXIT_FAILURE;
    }

    const int result = compress2(compressed, &compressed_size, data, data_size,
                                 Z_BEST_COMPRESSION);
    if (result != Z_OK) {
        fprintf(stderr, "Compression failed: %d\n", result);
        free(compressed);
        return EXIT_FAILURE;
    }

    for (uLongf i = 0; i < compressed_size; ++i) {
        printf("%02x", (unsigned int)compressed[i]);
    }
    putchar('\n');

    free(compressed);
    return EXIT_SUCCESS;
}
