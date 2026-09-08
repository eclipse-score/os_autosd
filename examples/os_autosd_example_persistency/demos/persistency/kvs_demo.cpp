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

/**
 * @file kvs_demo.cpp
 * @brief Comprehensive demonstration of the C++ KVS (Key-Value Storage) library
 *
 * This program showcases the main capabilities of the persistency library:
 * - Creating and configuring KVS instances
 * - Working with different data types (integers, floats, booleans, strings, arrays, objects)
 * - Snapshot management and restoration
 * - Default values handling
 * - Persistence and file operations
 * - Thread-safe operations
 */

#include "kvsbuilder.hpp"
// #include "internal/kvs_helper.hpp"  // Internal API not publicly available
#include <iostream>
#include <iomanip>
#include <vector>
#include <string>
#include <memory>
#include <cstdint>
#include <fstream>

using namespace score::mw::per::kvs;

// Color codes for better CLI output
const std::string RESET = "\033[0m";
const std::string BOLD = "\033[1m";
const std::string GREEN = "\033[32m";
const std::string BLUE = "\033[34m";
const std::string YELLOW = "\033[33m";
const std::string RED = "\033[31m";
const std::string CYAN = "\033[36m";

class KvsDemo {
private:
    std::string data_dir;

    void printHeader(const std::string& title) {
        std::cout << "\n" << BOLD << BLUE << "=" << std::string(60, '=') << "=" << RESET << "\n";
        std::cout << BOLD << CYAN << "  " << title << RESET << "\n";
        std::cout << BOLD << BLUE << "=" << std::string(60, '=') << "=" << RESET << "\n\n";
    }

    void printSubHeader(const std::string& subtitle) {
        std::cout << BOLD << YELLOW << "→ " << subtitle << RESET << "\n";
    }

    void printSuccess(const std::string& message) {
        std::cout << GREEN << "✓ " << message << RESET << "\n";
    }

    void printInfo(const std::string& message) {
        std::cout << BLUE << "ℹ " << message << RESET << "\n";
    }

    void printError(const std::string& message) {
        std::cout << RED << "✗ " << message << RESET << "\n";
    }

    void printKvsValue(const std::string& key, const KvsValue& value) {
        std::cout << "  " << BOLD << key << RESET << " = ";

        switch (value.getType()) {
            case KvsValue::Type::i32:
                std::cout << GREEN << std::get<int32_t>(value.getValue()) << RESET << " (i32)\n";
                break;
            case KvsValue::Type::u32:
                std::cout << GREEN << std::get<uint32_t>(value.getValue()) << RESET << " (u32)\n";
                break;
            case KvsValue::Type::i64:
                std::cout << GREEN << std::get<int64_t>(value.getValue()) << RESET << " (i64)\n";
                break;
            case KvsValue::Type::u64:
                std::cout << GREEN << std::get<uint64_t>(value.getValue()) << RESET << " (u64)\n";
                break;
            case KvsValue::Type::f64:
                std::cout << GREEN << std::fixed << std::setprecision(2)
                         << std::get<double>(value.getValue()) << RESET << " (f64)\n";
                break;
            case KvsValue::Type::Boolean:
                std::cout << GREEN << (std::get<bool>(value.getValue()) ? "true" : "false")
                         << RESET << " (boolean)\n";
                break;
            case KvsValue::Type::String:
                std::cout << GREEN << "\"" << std::get<std::string>(value.getValue()) << "\""
                         << RESET << " (string)\n";
                break;
            case KvsValue::Type::Null:
                std::cout << GREEN << "null" << RESET << " (null)\n";
                break;
            case KvsValue::Type::Array:
                std::cout << GREEN << "[array with " << std::get<KvsValue::Array>(value.getValue()).size()
                         << " elements]" << RESET << " (array)\n";
                break;
            case KvsValue::Type::Object:
                std::cout << GREEN << "{object with " << std::get<KvsValue::Object>(value.getValue()).size()
                         << " properties}" << RESET << " (object)\n";
                break;
        }
    }

public:
    KvsDemo(const std::string& dir) : data_dir(dir) {}

    void demonstrateBasicOperations() {
        printHeader("Basic KVS Operations Demo");

        printSubHeader("Creating KVS instance");
        auto builder_result = KvsBuilder(InstanceId(1))
            .need_defaults_flag(false)
            .need_kvs_flag(false)
            .dir(std::string(data_dir))
            .build();

        if (!builder_result) {
            printError("Failed to create KVS instance - Error code: " + std::to_string(static_cast<int>(static_cast<ErrorCode>(*builder_result.error()))));
            return;
        }

        Kvs kvs = std::move(builder_result.value());
        printSuccess("KVS instance created successfully");

        printSubHeader("Setting different data types");

        // Demonstrate different data types
        kvs.set_value("temperature", KvsValue(static_cast<int32_t>(23)));
        kvs.set_value("humidity", KvsValue(65.5));
        kvs.set_value("is_active", KvsValue(true));
        kvs.set_value("device_name", KvsValue(std::string("Sensor-001")));
        kvs.set_value("status", KvsValue(std::string("online")));
        kvs.set_value("null_value", KvsValue(nullptr));

        printSuccess("Set 6 different values");

        printSubHeader("Reading and displaying values");

        auto keys_result = kvs.get_all_keys();
        if (keys_result) {
            for (const auto& key : keys_result.value()) {
                auto value_result = kvs.get_value(key);
                if (value_result) {
                    printKvsValue(key, value_result.value());
                }
            }
        }

        printSubHeader("Key existence checks");

        std::vector<std::string> test_keys = {"temperature", "humidity", "nonexistent_key"};
        for (const auto& key : test_keys) {
            auto exists_result = kvs.key_exists(key);
            if (exists_result) {
                if (exists_result.value()) {
                    printSuccess("Key '" + key + "' exists");
                } else {
                    printInfo("Key '" + key + "' does not exist");
                }
            }
        }

        printSubHeader("Removing a key");
        auto remove_result = kvs.remove_key("null_value");
        if (remove_result) {
            printSuccess("Removed key 'null_value'");
        } else {
            printError("Failed to remove key 'null_value'");
        }

        printSubHeader("Persisting data");
        auto flush_result = kvs.flush();
        if (flush_result) {
            printSuccess("Data persisted to storage");
        } else {
            printError("Failed to persist data");
        }

        printInfo("Total keys after operations: " + std::to_string(kvs.get_all_keys().value_or(std::vector<std::string>{}).size()));
    }

    void demonstrateArraysAndObjects() {
        printHeader("Arrays and Objects Demo");

        auto builder_result = KvsBuilder(InstanceId(2))
            .need_defaults_flag(false)
            .need_kvs_flag(false)
            .dir(std::string(data_dir))
            .build();

        if (!builder_result) {
            printError("Failed to create KVS instance - Error code: " + std::to_string(static_cast<int>(static_cast<ErrorCode>(*builder_result.error()))));
            return;
        }

        Kvs kvs = std::move(builder_result.value());

        printSubHeader("Creating and storing arrays");

        // Create an array of sensor readings
        KvsValue::Array sensor_readings;
        sensor_readings.push_back(std::make_shared<KvsValue>(KvsValue(23.5)));
        sensor_readings.push_back(std::make_shared<KvsValue>(KvsValue(24.1)));
        sensor_readings.push_back(std::make_shared<KvsValue>(KvsValue(22.8)));

        kvs.set_value("sensor_readings", KvsValue(sensor_readings));
        printSuccess("Created array with 3 sensor readings");

        printSubHeader("Creating and storing objects");

        // Create a nested object
        KvsValue::Object device_config;
        device_config["name"] = std::make_shared<KvsValue>(KvsValue(std::string("Temperature Sensor")));
        device_config["id"] = std::make_shared<KvsValue>(KvsValue(static_cast<int32_t>(1001)));
        device_config["enabled"] = std::make_shared<KvsValue>(KvsValue(true));
        device_config["location"] = std::make_shared<KvsValue>(KvsValue(std::string("Room A")));

        kvs.set_value("device_config", KvsValue(device_config));
        printSuccess("Created object with device configuration");

        printSubHeader("Reading complex data structures");

        auto keys_result = kvs.get_all_keys();
        if (keys_result) {
            for (const auto& key : keys_result.value()) {
                auto value_result = kvs.get_value(key);
                if (value_result) {
                    printKvsValue(key, value_result.value());
                }
            }
        }

        kvs.flush();
        printSuccess("Complex data structures persisted");
    }

    void demonstrateSnapshots() {
        printHeader("Snapshot Management Demo");

        auto builder_result = KvsBuilder(InstanceId(3))
            .need_defaults_flag(false)
            .need_kvs_flag(false)
            .dir(std::string(data_dir))
            .build();

        if (!builder_result) {
            printError("Failed to create KVS instance - Error code: " + std::to_string(static_cast<int>(static_cast<ErrorCode>(*builder_result.error()))));
            return;
        }

        Kvs kvs = std::move(builder_result.value());

        printSubHeader("Setting up initial data");
        kvs.set_value("version", KvsValue(static_cast<int32_t>(1)));
        kvs.set_value("config", KvsValue(std::string("initial")));
        kvs.flush();
        printSuccess("Initial data created");

        auto max_snapshots = kvs.snapshot_max_count();
        printInfo("Maximum snapshots allowed: " + std::to_string(max_snapshots));

        printSubHeader("Creating snapshots with data changes");

        for (int i = 2; i <= 4; ++i) {
            kvs.set_value("version", KvsValue(static_cast<int32_t>(i)));
            kvs.set_value("config", KvsValue(std::string("config_v") + std::to_string(i)));

            auto flush_result = kvs.flush();
            if (flush_result) {
                auto snapshot_count_result = kvs.snapshot_count();
                auto count = snapshot_count_result ? snapshot_count_result.value() : 0;
                printSuccess("Created snapshot " + std::to_string(i) + " (total: " +
                           std::to_string(count) + ")");
            }
        }

        printSubHeader("Current state before restoration");
        auto current_version = kvs.get_value("version");
        auto current_config = kvs.get_value("config");
        if (current_version && current_config) {
            printKvsValue("version", current_version.value());
            printKvsValue("config", current_config.value());
        }

        printSubHeader("Restoring from snapshot 1");
        auto restore_result = kvs.snapshot_restore(SnapshotId(1));
        if (restore_result) {
            printSuccess("Successfully restored from snapshot 1");

            auto restored_version = kvs.get_value("version");
            auto restored_config = kvs.get_value("config");
            if (restored_version && restored_config) {
                printKvsValue("version", restored_version.value());
                printKvsValue("config", restored_config.value());
            }
        } else {
            printError("Failed to restore from snapshot 1");
        }
    }

    /* Commented out - requires internal API
    void createDefaultsFile(InstanceId instance_id) {
        std::string defaults_file_path = data_dir + "/kvs_" + std::to_string(instance_id.id) + "_default.json";
        std::string defaults_hash_path = data_dir + "/kvs_" + std::to_string(instance_id.id) + "_default.hash";

        // Create JSON in flat format (like C++ tests)
        std::string defaults_content = R"({
    "theme": {
        "t": "str",
        "v": "dark"
    },
    "language": {
        "t": "str",
        "v": "en"
    },
    "timeout": {
        "t": "i32",
        "v": 30
    },
    "auto_save": {
        "t": "bool",
        "v": true
    },
    "max_connections": {
        "t": "i32",
        "v": 100
    }
})";

        // Create JSON file
        std::ofstream defaults_file(defaults_file_path);
        if (defaults_file.is_open()) {
            defaults_file << defaults_content;
            defaults_file.close();
        } else {
            printError("Failed to create defaults file: " + defaults_file_path);
            return;
        }

        // Create hash file using persistency's Adler-32 implementation
        uint32_t defaults_hash = calculate_hash_adler32(defaults_content);
        std::array<uint8_t, 4> hash_bytes = get_hash_bytes_adler32(defaults_hash);

        std::ofstream defaults_hash_file(defaults_hash_path, std::ios::binary);
        if (defaults_hash_file.is_open()) {
            defaults_hash_file.write(reinterpret_cast<const char*>(hash_bytes.data()), 4);
            defaults_hash_file.close();
        } else {
            printError("Failed to create defaults hash file: " + defaults_hash_path);
        }
    }

    */ // End of commented createDefaultsFile

    /* Commented out - requires internal API
    void demonstrateDefaults() {
        printHeader("Default Values Demo");

        InstanceId instance_id(5);

        printSubHeader("Creating defaults file manually (as required by persistency)");
        createDefaultsFile(instance_id);
        printSuccess("Defaults file created manually");

        printSubHeader("Creating KVS with required defaults");
        auto builder_result = KvsBuilder(instance_id)
            .need_defaults_flag(true)   // Require defaults file
            .need_kvs_flag(false)
            .dir(std::string(data_dir))
            .build();

        if (!builder_result) {
            printError("Failed to create KVS instance with defaults - Error code: " + std::to_string(static_cast<int>(static_cast<ErrorCode>(*builder_result.error()))));
            return;
        }

        Kvs kvs = std::move(builder_result.value());
        printSuccess("KVS instance created with defaults");

        printSubHeader("Reading default values");

        std::vector<std::string> default_keys = {"theme", "language", "timeout", "auto_save", "max_connections"};
        for (const auto& key : default_keys) {
            auto default_result = kvs.get_default_value(key);
            if (default_result) {
                std::cout << "  Default ";
                printKvsValue(key, default_result.value());
            }
        }

        printSubHeader("Overriding some defaults");
        kvs.set_value("theme", KvsValue(std::string("light")));
        kvs.set_value("timeout", KvsValue(static_cast<int32_t>(60)));
        printSuccess("Overrode 'theme' and 'timeout' values");

        printSubHeader("Current values (mix of defaults and overrides)");
        for (const auto& key : default_keys) {
            auto value_result = kvs.get_value(key);
            if (value_result) {
                auto is_default = !kvs.key_exists(key).value_or(false);
                std::cout << "  " << (is_default ? "(default) " : "(custom)  ");
                printKvsValue(key, value_result.value());
            }
        }

        printSubHeader("Resetting a key to default");
        auto reset_result = kvs.reset_key("theme");
        if (reset_result) {
            printSuccess("Reset 'theme' to default value");
            auto value_result = kvs.get_value("theme");
            if (value_result) {
                std::cout << "  ";
                printKvsValue("theme", value_result.value());
            }
        }

        kvs.flush();
        printSuccess("Configuration saved with defaults");
    }

    */ // End of commented demonstrateDefaults

    void demonstrateReset() {
        printHeader("Reset Operations Demo");


        auto builder_result = KvsBuilder(InstanceId(6))
            .need_defaults_flag(false)
            .need_kvs_flag(false)
            .dir(std::string(data_dir))
            .build();

        if (!builder_result) {
            printError("Failed to create KVS instance - Error code: " + std::to_string(static_cast<int>(static_cast<ErrorCode>(*builder_result.error()))));
            return;
        }

        Kvs kvs = std::move(builder_result.value());

        printSubHeader("Adding test data");
        kvs.set_value("test1", KvsValue(std::string("value1")));
        kvs.set_value("test2", KvsValue(static_cast<int32_t>(42)));
        kvs.set_value("test3", KvsValue(true));

        auto initial_count = kvs.get_all_keys().value_or(std::vector<std::string>{}).size();
        printSuccess("Added " + std::to_string(initial_count) + " test entries");

        printSubHeader("Performing complete reset");
        auto reset_result = kvs.reset();
        if (reset_result) {
            auto final_count = kvs.get_all_keys().value_or(std::vector<std::string>{}).size();
            printSuccess("Reset complete - " + std::to_string(final_count) + " entries remaining");

            if (final_count == 0) {
                printSuccess("KVS is now empty");
            }
        } else {
            printError("Reset failed");
        }
    }

    void run() {
        std::cout << BOLD << GREEN << "\n🚀 KVS C++ Library Demonstration Program" << RESET << "\n";
        std::cout << BLUE << "Data directory: " << data_dir << RESET << "\n\n";

        printInfo("Press Enter to continue between demonstrations...");

        demonstrateBasicOperations();
        std::cout << "\n" << YELLOW << "Press Enter to continue..." << RESET;
        std::cin.get();

        demonstrateArraysAndObjects();
        std::cout << "\n" << YELLOW << "Press Enter to continue..." << RESET;
        std::cin.get();

        demonstrateSnapshots();
        std::cout << "\n" << YELLOW << "Press Enter to continue..." << RESET;
        std::cin.get();

        // demonstrateDefaults();  // Requires internal API - commented out for now
        // std::cout << "\n" << YELLOW << "Press Enter to continue..." << RESET;
        // std::cin.get();

        demonstrateReset();

        printHeader("Demonstration Complete");
        printSuccess("All KVS features have been demonstrated!");
        printInfo("Check the files in '" + data_dir + "' to see the persisted data");

        std::cout << BOLD << GREEN << "\n✨ Thank you for exploring the KVS C++ library!" << RESET << "\n\n";
    }
};

int main(int argc, char* argv[]) {
    std::string data_dir = "./kvs_demo_data";

    if (argc > 1) {
        data_dir = argv[1];
    }

    // Create data directory if it doesn't exist
    // Using system() for simplicity - in production code you'd use proper directory creation
    std::string mkdir_cmd = "mkdir -p " + data_dir;
    system(mkdir_cmd.c_str());

    try {
        KvsDemo demo(data_dir);
        demo.run();
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}
