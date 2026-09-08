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
#include "protocol.h"
#include <unistd.h>
#include <string.h>
#include <errno.h>

int send_message(int sockfd, const message_t *msg) {
    ssize_t bytes_sent = 0;
    ssize_t total_size = sizeof(message_header_t) + msg->header.length;
    const char *data = (const char *)msg;

    while (bytes_sent < total_size) {
        ssize_t result = write(sockfd, data + bytes_sent, total_size - bytes_sent);
        if (result <= 0) {
            if (result == -1 && errno == EINTR) {
                continue;
            }
            return -1;
        }
        bytes_sent += result;
    }

    return 0;
}

int recv_message(int sockfd, message_t *msg) {
    ssize_t bytes_received = 0;
    char *data = (char *)msg;

    while (bytes_received < sizeof(message_header_t)) {
        ssize_t result = read(sockfd, data + bytes_received,
                             sizeof(message_header_t) - bytes_received);
        if (result <= 0) {
            if (result == -1 && errno == EINTR) {
                continue;
            }
            return -1;
        }
        bytes_received += result;
    }

    if (msg->header.length > 0) {
        while (bytes_received < sizeof(message_header_t) + msg->header.length) {
            ssize_t result = read(sockfd, data + bytes_received,
                                 sizeof(message_header_t) + msg->header.length - bytes_received);
            if (result <= 0) {
                if (result == -1 && errno == EINTR) {
                    continue;
                }
                return -1;
            }
            bytes_received += result;
        }
    }

    return 0;
}
