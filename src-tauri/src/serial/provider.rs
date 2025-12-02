use crate::{
    events::frontend_events::UpdateStatus,
    serial::tycmd::{tycmd_list, tycmd_watch},
    state::AppState,
};

use async_trait::async_trait;
use tauri::{AppHandle, Manager};

pub trait DeviceProvider: Send + Sync {
    fn start(&self, app_handle: &AppHandle);
}

#[async_trait]
pub trait FirmwareUpdater: Send + Sync {
    async fn update_firmware(
        &self,
        firmware_path: &str,
        board_tag: &str,
        on_progress: Box<dyn Fn(UpdateStatus) + Send + Sync>,
    ) -> Result<(), anyhow::Error>;
}

#[derive(Default)]
pub struct TycmdProvider;

impl DeviceProvider for TycmdProvider {
    fn start(&self, app_handle: &AppHandle) {
        let handle = app_handle.clone();

        tauri::async_runtime::spawn(async move {
            tycmd_list(&handle).await;

            let initial_state_update_app_handle = handle.clone();

            tauri::async_runtime::spawn(async move {
                let state = initial_state_update_app_handle.state::<AppState>();

                let mut state_guard = state.lock().await;

                let _ = state_guard.emit_device_state_update(&initial_state_update_app_handle);

                drop(state_guard);
            });

            tycmd_watch(&handle).await;
        });
    }
}
