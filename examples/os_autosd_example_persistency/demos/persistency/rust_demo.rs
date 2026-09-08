/**
 * Standalone demonstration of key-value storage concepts
 *
 * This program demonstrates key-value storage concepts without external dependencies:
 * - Basic key-value operations
 * - Working with different data types
 * - JSON-based persistence simulation
 * - File I/O operations
 *
 * Note: This is a simplified standalone demo. For full KVS functionality,
 * install and use the persistency Rust library (rust_kvs).
 */

use rust_kvs::prelude::*;
use std::io::{self, Write};
use std::path::PathBuf;

// Color codes for better CLI output
const RESET: &str = "\x1b[0m";
const BOLD: &str = "\x1b[1m";
const GREEN: &str = "\x1b[32m";
const BLUE: &str = "\x1b[34m";
const YELLOW: &str = "\x1b[33m";
const RED: &str = "\x1b[31m";
const CYAN: &str = "\x1b[36m";

struct KvsDemo {
    data_dir: String,
}

impl KvsDemo {
    fn new(data_dir: String) -> Self {
        Self { data_dir }
    }

    fn print_header(&self, title: &str) {
        println!("\n{}{}{}{}{}",
                 BOLD, BLUE,
                 "=".repeat(60),
                 RESET, "\n");
        println!("{}{}  {}{}", BOLD, CYAN, title, RESET);
        println!("{}{}{}{}",
                 BOLD, BLUE,
                 "=".repeat(60),
                 RESET);
        println!();
    }

    fn print_sub_header(&self, subtitle: &str) {
        println!("{}{}→ {}{}", BOLD, YELLOW, subtitle, RESET);
    }

    fn print_success(&self, message: &str) {
        println!("{}✓ {}{}", GREEN, message, RESET);
    }

    fn print_info(&self, message: &str) {
        println!("{}ℹ {}{}", BLUE, message, RESET);
    }

    fn print_error(&self, message: &str) {
        println!("{}✗ {}{}", RED, message, RESET);
    }

    fn print_kvs_value(&self, key: &str, value: &KvsValue) {
        print!("  {}{}{} = ", BOLD, key, RESET);

        match value {
            KvsValue::I32(v) => println!("{}{}{} (i32)", GREEN, v, RESET),
            KvsValue::U32(v) => println!("{}{}{} (u32)", GREEN, v, RESET),
            KvsValue::I64(v) => println!("{}{}{} (i64)", GREEN, v, RESET),
            KvsValue::U64(v) => println!("{}{}{} (u64)", GREEN, v, RESET),
            KvsValue::F64(v) => println!("{}{:.2}{} (f64)", GREEN, v, RESET),
            KvsValue::Boolean(v) => println!("{}{}{} (boolean)", GREEN, v, RESET),
            KvsValue::String(v) => println!("{}\"{}\" (string){}", GREEN, v, RESET),
            KvsValue::Null => println!("{}null{} (null)", GREEN, RESET),
            KvsValue::Array(v) => println!("{}[array with {} elements]{} (array)", GREEN, v.len(), RESET),
            KvsValue::Object(v) => println!("{}{{object with {} properties}}{} (object)", GREEN, v.len(), RESET),
        }
    }

    fn demonstrate_basic_operations(&self) -> Result<(), ErrorCode> {
        self.print_header("Basic KVS Operations Demo");

        self.print_sub_header("Creating KVS instance");
        let builder = KvsBuilder::new(InstanceId(1))
            .dir(self.data_dir.clone())
            .kvs_load(KvsLoad::Optional);
        let kvs = builder.build()?;
        self.print_success("KVS instance created successfully");

        self.print_sub_header("Setting different data types");

        // Demonstrate different data types
        kvs.set_value("temperature", 23i32)?;
        kvs.set_value("humidity", 65.5f64)?;
        kvs.set_value("is_active", true)?;
        kvs.set_value("device_name", "Sensor-001")?;
        kvs.set_value("status", "online")?;
        kvs.set_value("null_value", ())?;

        self.print_success("Set 6 different values");

        self.print_sub_header("Reading and displaying values");

        let keys = kvs.get_all_keys()?;
        for key in keys {
            let value = kvs.get_value(&key)?;
            self.print_kvs_value(&key, &value);
        }

        self.print_sub_header("Key existence checks");

        let test_keys = ["temperature", "humidity", "nonexistent_key"];
        for key in &test_keys {
            if kvs.key_exists(key)? {
                self.print_success(&format!("Key '{}' exists", key));
            } else {
                self.print_info(&format!("Key '{}' does not exist", key));
            }
        }

        self.print_sub_header("Removing a key");
        kvs.remove_key("null_value")?;
        self.print_success("Removed key 'null_value'");

        self.print_sub_header("Persisting data");
        kvs.flush()?;
        self.print_success("Data persisted to storage");

        let final_keys = kvs.get_all_keys()?;
        self.print_info(&format!("Total keys after operations: {}", final_keys.len()));

        Ok(())
    }

    fn demonstrate_arrays_and_objects(&self) -> Result<(), ErrorCode> {
        self.print_header("Arrays and Objects Demo");

        let builder = KvsBuilder::new(InstanceId(2))
            .dir(self.data_dir.clone())
            .kvs_load(KvsLoad::Optional);
        let kvs = builder.build()?;

        self.print_sub_header("Creating and storing arrays");

        // Create an array of sensor readings
        let sensor_readings = vec![
            KvsValue::from(23.5),
            KvsValue::from(24.1),
            KvsValue::from(22.8),
        ];

        kvs.set_value("sensor_readings", sensor_readings)?;
        self.print_success("Created array with 3 sensor readings");

        self.print_sub_header("Creating and storing objects");

        // Create a nested object
        let device_config = KvsMap::from([
            ("name".to_string(), KvsValue::from("Temperature Sensor")),
            ("id".to_string(), KvsValue::from(1001i32)),
            ("enabled".to_string(), KvsValue::from(true)),
            ("location".to_string(), KvsValue::from("Room A")),
        ]);

        kvs.set_value("device_config", device_config)?;
        self.print_success("Created object with device configuration");

        self.print_sub_header("Reading complex data structures");

        let keys = kvs.get_all_keys()?;
        for key in keys {
            let value = kvs.get_value(&key)?;
            self.print_kvs_value(&key, &value);
        }

        kvs.flush()?;
        self.print_success("Complex data structures persisted");

        Ok(())
    }

    fn demonstrate_snapshots(&self) -> Result<(), ErrorCode> {
        self.print_header("Snapshot Management Demo");

        let builder = KvsBuilder::new(InstanceId(3))
            .dir(self.data_dir.clone())
            .kvs_load(KvsLoad::Optional);
        let kvs = builder.build()?;

        self.print_sub_header("Setting up initial data");
        kvs.set_value("version", 1i32)?;
        kvs.set_value("config", "initial")?;
        kvs.flush()?;
        self.print_success("Initial data created");

        let max_snapshots = kvs.snapshot_max_count();
        self.print_info(&format!("Maximum snapshots allowed: {}", max_snapshots));

        self.print_sub_header("Creating snapshots with data changes");

        for i in 2..=4 {
            kvs.set_value("version", i)?;
            kvs.set_value("config", format!("config_v{}", i))?;

            kvs.flush()?;
            let snapshot_count = kvs.snapshot_count();
            self.print_success(&format!(
                "Created snapshot {} (total: {})",
                i, snapshot_count
            ));
        }

        self.print_sub_header("Current state before restoration");
        let current_version = kvs.get_value("version")?;
        let current_config = kvs.get_value("config")?;
        self.print_kvs_value("version", &current_version);
        self.print_kvs_value("config", &current_config);

        self.print_sub_header("Restoring from snapshot 1");
        kvs.snapshot_restore(SnapshotId(1))?;
        self.print_success("Successfully restored from snapshot 1");

        let restored_version = kvs.get_value("version")?;
        let restored_config = kvs.get_value("config")?;
        self.print_kvs_value("version", &restored_version);
        self.print_kvs_value("config", &restored_config);

        Ok(())
    }

    fn create_defaults_file(&self, instance_id: InstanceId) -> Result<(), ErrorCode> {
        let defaults_file_path = PathBuf::from(&self.data_dir)
            .join(format!("kvs_{}_default.json", instance_id.0));

        let kvs_value = KvsValue::from(KvsMap::from([
            ("theme".to_string(), KvsValue::from("dark")),
            ("language".to_string(), KvsValue::from("en")),
            ("timeout".to_string(), KvsValue::from(30i32)),
            ("auto_save".to_string(), KvsValue::from(true)),
            ("max_connections".to_string(), KvsValue::from(100i32)),
        ]));

        // Create JSON in the persistency format with type and value fields
        let json_str = r#"{
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
}"#;
        std::fs::write(&defaults_file_path, json_str)?;

        Ok(())
    }

    fn demonstrate_defaults(&self) -> Result<(), ErrorCode> {
        self.print_header("Default Values Demo");

        let instance_id = InstanceId(5);

        self.print_sub_header("Creating defaults file manually (as required by persistency)");
        self.create_defaults_file(instance_id)?;
        self.print_success("Defaults file created manually");

        self.print_sub_header("Creating KVS with required defaults");
        let builder = KvsBuilder::new(instance_id)
            .dir(self.data_dir.clone())
            .defaults(KvsDefaults::Required);
        let kvs = builder.build()?;
        self.print_success("KVS instance created with defaults");

        self.print_sub_header("Reading default values");

        let default_keys = ["theme", "language", "timeout", "auto_save", "max_connections"];
        for key in &default_keys {
            match kvs.get_default_value(key) {
                Ok(value) => {
                    print!("  Default ");
                    self.print_kvs_value(key, &value);
                }
                Err(_) => {
                    self.print_error(&format!("Could not get default value for '{}'", key));
                }
            }
        }

        self.print_sub_header("Overriding some defaults");
        kvs.set_value("theme", "light")?;
        kvs.set_value("timeout", 60i32)?;
        self.print_success("Overrode 'theme' and 'timeout' values");

        self.print_sub_header("Current values (mix of defaults and overrides)");
        for key in &default_keys {
            if let Ok(value) = kvs.get_value(key) {
                let is_default = !kvs.key_exists(key)?;
                let prefix = if is_default { "(default) " } else { "(custom)  " };
                print!("  {}", prefix);
                self.print_kvs_value(key, &value);
            }
        }

        self.print_sub_header("Resetting a key to default");
        kvs.reset_key("theme")?;
        self.print_success("Reset 'theme' to default value");
        let value = kvs.get_value("theme")?;
        print!("  ");
        self.print_kvs_value("theme", &value);

        kvs.flush()?;
        self.print_success("Configuration saved with defaults");

        Ok(())
    }

    fn demonstrate_reset(&self) -> Result<(), ErrorCode> {
        self.print_header("Reset Operations Demo");


        let builder = KvsBuilder::new(InstanceId(6))
            .dir(self.data_dir.clone())
            .kvs_load(KvsLoad::Optional);
        let kvs = builder.build()?;

        self.print_sub_header("Adding test data");
        kvs.set_value("test1", "value1")?;
        kvs.set_value("test2", 42i32)?;
        kvs.set_value("test3", true)?;

        let initial_count = kvs.get_all_keys()?.len();
        self.print_success(&format!("Added {} test entries", initial_count));

        self.print_sub_header("Performing complete reset");
        kvs.reset()?;
        let final_count = kvs.get_all_keys()?.len();
        self.print_success(&format!(
            "Reset complete - {} entries remaining",
            final_count
        ));

        if final_count == 0 {
            self.print_success("KVS is now empty");
        }

        Ok(())
    }

    fn wait_for_user(&self) {
        print!("\n{}Press Enter to continue...{}", YELLOW, RESET);
        io::stdout().flush().unwrap();
        let mut input = String::new();
        io::stdin().read_line(&mut input).unwrap();
    }

    fn run(&self) -> Result<(), ErrorCode> {
        println!("{}{}🚀 KVS Rust Library Demonstration Program{}",
                 BOLD, GREEN, RESET);
        println!("{}Data directory: {}{}", BLUE, self.data_dir, RESET);
        println!();

        self.print_info("Press Enter to continue between demonstrations...");

        self.demonstrate_basic_operations()?;
        self.wait_for_user();

        self.demonstrate_arrays_and_objects()?;
        self.wait_for_user();

        self.demonstrate_snapshots()?;
        self.wait_for_user();

        match self.demonstrate_defaults() {
            Ok(_) => {}
            Err(e) => {
                self.print_error(&format!("Defaults demo failed: {:?}", e));
                self.print_info("This is expected if defaults file creation failed");
            }
        }
        self.wait_for_user();

        self.demonstrate_reset()?;

        self.print_header("Demonstration Complete");
        self.print_success("All KVS features have been demonstrated!");
        self.print_info(&format!(
            "Check the files in '{}' to see the persisted data",
            self.data_dir
        ));

        println!("\n{}{}✨ Thank you for exploring the KVS Rust library!{}{}\n",
                 BOLD, GREEN, RESET, "\n");

        Ok(())
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let data_dir = if args.len() > 1 {
        args[1].clone()
    } else {
        "./rust_demo_data".to_string()
    };

    // Create data directory if it doesn't exist
    if let Err(e) = std::fs::create_dir_all(&data_dir) {
        eprintln!("{}Failed to create directory '{}': {}{}", RED, data_dir, e, RESET);
        std::process::exit(1);
    }

    let demo = KvsDemo::new(data_dir);
    if let Err(e) = demo.run() {
        eprintln!("{}Demo failed: {:?}{}", RED, e, RESET);
        std::process::exit(1);
    }
}