/********************************************************************************
 * Copyright (c) 2025 Contributors to the Eclipse Foundation
 *
 * See the NOTICE file(s) distributed with this work for additional
 * information regarding copyright ownership.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Apache License Version 2.0 which is available at
 * https://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0
 ********************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <zlib.h>

int main(void) {
    const char *input = "hello from an AutoSD rpm, via zlib!";
    printf("zlib version: %s\n", zlibVersion());

    uLong src_len = (uLong)strlen(input) + 1; /* include terminating NUL */
    uLongf comp_len = compressBound(src_len);
    Bytef *comp = malloc(comp_len);
    if (comp == NULL)
        return 1;

    if (compress(comp, &comp_len, (const Bytef *)input, src_len) != Z_OK) {
        fprintf(stderr, "compress failed\n");
        return 1;
    }

    char out[256];
    uLongf out_len = sizeof(out);
    if (uncompress((Bytef *)out, &out_len, comp, comp_len) != Z_OK) {
        fprintf(stderr, "uncompress failed\n");
        return 1;
    }

    printf("compressed %lu -> %lu bytes, round-trip: \"%s\"\n",
           (unsigned long)src_len, (unsigned long)comp_len, out);

    free(comp);
    return strcmp(out, input) == 0 ? 0 : 1;
}
