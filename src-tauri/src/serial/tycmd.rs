use std::future::Future;
use std::pin::Pin;

use serde::{Deserialize, Serialize};
use tauri::{AppHandle, Manager};
use tauri_plugin_shell::process::CommandEvent;
use tauri_plugin_shell::ShellExt;

use crate::firmware::{determine_device_type, ConnectedDevice, DeviceType};
use crate::state::AppState;

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct TyCmdListEntry {
    pub action: String,
    pub capabilities: Vec<String>,
    pub description: String,
    pub interfaces: Vec<Vec<String>>,
    pub location: String,
    pub model: String,
    pub serial: String,
    pub tag: String,
}

type BoxedFuture<'a> = Pin<Box<dyn Future<Output = Option<()>> + Send + 'a>>;

pub struct TyCmdUpdater {
    pub app_handle: AppHandle,
}

pub fn process_tycmd_list_entry(
    event: CommandEvent,
    app_handle: AppHandle,
    buffer: &mut String,
) -> BoxedFuture<'_> {
    Box::pin(async move {
        if let CommandEvent::Stdout(line) = event {
            let output = match String::from_utf8(line) {
                Ok(output) => output.trim().to_owned(),
                Err(_) => return None,
            };

            buffer.push_str(&output);

            // Try to parse complete JSON objects from buffer
            let mut entries: Vec<TyCmdListEntry> = Vec::new();
            let mut processed_bytes = 0;

            let buffer_str = buffer.as_str();
            let mut remaining_buffer = buffer_str;

            while !remaining_buffer.is_empty() {
                let mut brace_count = 0;
                let mut end_pos = 0;
                let mut found_complete = false;

                for (i, ch) in remaining_buffer.char_indices() {
                    match ch {
                        '{' => brace_count += 1,
                        '}' => {
                            brace_count -= 1;
                            if brace_count == 0 {
                                end_pos = i + 1;
                                found_complete = true;
                                break;
                            }
                        }
                        _ => {}
                    }
                }

                if !found_complete {
                    break;
                }

                let json_str = &remaining_buffer[..end_pos];
                log::info!("Attempting to parse JSON: {}", json_str);

                match serde_json::from_str::<TyCmdListEntry>(json_str) {
                    Ok(entry) => {
                        log::info!("matched: {:?}", entry);
                        entries.push(entry);
                        processed_bytes += json_str.len();
                        remaining_buffer = remaining_buffer[end_pos..].trim_start();
                        processed_bytes += end_pos - json_str.len();
                    }
                    Err(e) => {
                        log::info!("Failed to parse JSON: {}", e);
                        remaining_buffer = &remaining_buffer[1..];
                        processed_bytes += 1;
                    }
                }
            }

            buffer.drain(..processed_bytes);

            // Process parsed entries
            for entry in entries {
                let device_type = determine_device_type(&entry);
                log::info!("Device type is {:?}", device_type);

                if device_type == DeviceType::HEADLESS || device_type == DeviceType::UNKNOWN {
                    log::info!("Skipping headless/unknown device");

                    continue;
                }

                let state = app_handle.state::<AppState>();

                let mut state_guard = state.lock().await;

                let mut device = ConnectedDevice {
                    action_history: vec![entry.action.to_string()],
                    device_type,
                    ty_cmd_info: entry,
                    updated_at: chrono::Utc::now().timestamp_millis(),
                };

                log::info!("Valid device found: {:?}", device);

                match device.ty_cmd_info.action.as_str() {
                    "add" => {
                        log::info!("action is add. Setting device");

                        state_guard.device = Some(device);
                    }
                    "change" | "miss" => {
                        log::info!("action is change or miss");

                        if let Some(existing) = &state_guard.device {
                            let mut history = existing.action_history.clone();

                            history.push(device.ty_cmd_info.action.to_string());

                            const MAX_HISTORY: usize = 20;

                            if history.len() > MAX_HISTORY {
                                let overflow = history.len() - MAX_HISTORY;

                                history.drain(0..overflow);
                            }

                            device.action_history = history;
                        }

                        state_guard.device = Some(device);
                    }
                    "remove" => {
                        log::info!("action is remove. Clearing device");
                        state_guard.device = None;
                    }
                    _ => {}
                }

                state_guard.emit_device_state_update(&app_handle).ok();
            }
        }

        Some(())
    })
}

#[derive(PartialEq)]
enum InvokeTyCmd {
    List,
    Watch,
}

#[allow(clippy::type_complexity)]
async fn invoke_tycmd(
    command: InvokeTyCmd,
    callback: fn(event: CommandEvent, app_handle: AppHandle, buffer: &mut String) -> BoxedFuture,
    app_handle: &AppHandle,
) {
    let invoke_app_handle = app_handle.clone();

    let sidecar = invoke_app_handle
        .shell()
        .sidecar("tycmd")
        .unwrap()
        .set_raw_out(true)
        .args(if command == InvokeTyCmd::List {
            vec!["list", "--verbose", "--output", "json"]
        } else {
            vec!["list", "--verbose", "--watch", "--output", "json"]
        });

    // TODO: Handle the failed expectation
    let (mut rx, _child) = sidecar.spawn().expect("Failed to spawn tycmd");

    let mut buffer = String::new();

    while let Some(event) = rx.recv().await {
        let result = callback(event, invoke_app_handle.clone(), &mut buffer).await;

        if command == InvokeTyCmd::List && result == Some(()) {
            break;
        }
    }

    log::info!("Done receiving data from tycmd child process (tycmd.rs)");
}

pub async fn tycmd_list(app_handle: &AppHandle) {
    invoke_tycmd(InvokeTyCmd::List, process_tycmd_list_entry, app_handle).await;
}

pub async fn tycmd_watch(app_handle: &AppHandle) {
    let app_handle = app_handle.clone();

    tauri::async_runtime::spawn(async move {
        invoke_tycmd(InvokeTyCmd::Watch, process_tycmd_list_entry, &app_handle).await;
    });
}
