use std::collections::hash_map::DefaultHasher;
use std::collections::HashMap;
use std::hash::{Hash, Hasher};

use tauri::{AppHandle, Emitter};

use crate::events::frontend_events::FlashingStatus;
use crate::firmware::{ArchiveSource, ConnectedDevice};
use crate::serial::device::{DeviceState, DeviceStateUpdatePayload};

#[derive(Default)]
pub struct AppStateData {
    pub archive_source: ArchiveSource,
    pub cache_dir: Option<Box<tauri_plugin_fs::FilePath>>,
    pub device: Option<ConnectedDevice>,
    pub flashing: Option<FlashingStatus>,
    pub last_digest: Option<u64>,
    last_emitted_state: Option<DeviceState>,
    pub size: u64,
    pub temp_dir: Option<Box<tauri_plugin_fs::FilePath>>,
    pub version: String,
}

impl AppStateData {
    pub fn consolidated_state(&self) -> DeviceState {
        match (&self.device, &self.flashing) {
            (None, _) => DeviceState::Disconnected,
            (Some(device), Some(FlashingStatus::Downloading(status))) => DeviceState::Downloading {
                device: device.clone(),
                status: status.clone(),
            },
            (Some(device), Some(FlashingStatus::Updating(status))) => DeviceState::Updating {
                device: device.clone(),
                status: status.clone(),
            },
            (Some(device), None) => DeviceState::Ready {
                device: device.clone(),
            },
        }
    }

    pub fn emit_device_state_update(&mut self, app_handle: &AppHandle) -> tauri::Result<()> {
        if let Some(payload) = self.take_device_state_update() {
            log::info!("emit_device_state_update: Emitting {:?}", payload);

            match app_handle.emit_to("main", "device-state-update", &payload) {
                Ok(_) => {
                    log::info!("emit_device_state_update: Emitted {:?}", &payload);
                }
                Err(e) => {
                    log::error!("emit_device_state_update: Failed to emit {:?}", payload);
                    log::error!("{:?}", e);
                }
            }
        } else {
            log::info!("emit_device_state_update: No payload");
        }

        Ok(())
    }

    /// Prepares a payload if the consolidated state has changed.
    pub fn take_device_state_update(&mut self) -> Option<DeviceStateUpdatePayload> {
        let consolidated = self.consolidated_state();

        if self.last_emitted_state.as_ref() != Some(&consolidated) {
            self.last_emitted_state = Some(consolidated.clone());

            Some(DeviceStateUpdatePayload {
                state: consolidated,
            })
        } else {
            None
        }
    }
}

pub fn devices_digest(devices: &HashMap<String, ConnectedDevice>) -> u64 {
    let json = serde_json::to_string(devices).unwrap_or_default();

    let mut hasher = DefaultHasher::new();

    json.hash(&mut hasher);

    hasher.finish()
}

pub type AppState = tokio::sync::Mutex<AppStateData>;

#[cfg(test)]
mod tests {
    use super::*;
    use crate::firmware::{ConnectedDevice, DeviceType};
    use crate::serial::tycmd::TyCmdListEntry;

    fn sample_entry(serial: &str, tag: &str) -> TyCmdListEntry {
        TyCmdListEntry {
            action: "add".into(),
            capabilities: vec!["serial".into(), "run".into()],
            description: "M8".into(),
            interfaces: vec![vec!["Serial".into(), "/dev/tty.usb".into()]],
            location: "usb-1-1".into(),
            model: "Teensy 4.0".into(),
            serial: serial.into(),
            tag: tag.into(),
        }
    }

    fn sample_device(serial: &str, tag: &str) -> ConnectedDevice {
        ConnectedDevice {
            action_history: vec!["add".into()],
            device_type: DeviceType::MODEL01,
            ty_cmd_info: sample_entry(serial, tag),
            updated_at: 0,
        }
    }

    #[test]
    fn digest_changes_with_content() {
        let mut a: HashMap<String, ConnectedDevice> = HashMap::new();
        a.insert("dev1".into(), sample_device("123", "dev1"));

        let mut b = a.clone();
        b.insert("dev2".into(), sample_device("456", "dev2"));

        let da = devices_digest(&a);
        let db = devices_digest(&b);
        assert_ne!(da, db);

        // identical map yields identical digest
        let da2 = devices_digest(&a);
        assert_eq!(da, da2);
    }
}
