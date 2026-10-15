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

#include <string>
#include <vector>

extern "C" int helper_value(void);

int main() {
    const std::vector<std::string> values{"AutoSD", "S-CORE"};
    return values.size() == 2 && helper_value() == 42 ? 0 : 1;
}
