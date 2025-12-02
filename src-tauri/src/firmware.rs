use anyhow::{Error, Result};
use async_trait::async_trait;
use futures_util::StreamExt;
use reqwest::header::USER_AGENT;
use serde::{Deserialize, Serialize};
use std::{
    io::Write,
    path::{Path, PathBuf},
    sync::Arc,
};

use tauri::{http::HeaderMap, AppHandle, Manager};
use tauri_plugin_fs::{FilePath, FsExt, OpenOptions};
use tauri_plugin_shell::{process::CommandEvent, ShellExt};
use zip::ZipArchive;

use crate::{
    events::frontend_events::{
        DownloadState, DownloadStatus, FlashingStatus, UpdateState, UpdateStatus,
    },
    serial::{
        self,
        provider::FirmwareUpdater,
        tycmd::{TyCmdListEntry, TyCmdUpdater},
    },
    state::{AppState, AppStateData},
};

const KNOWN_M8_DESCRIPTIONS: [&str; 3] = ["HalfKay", "M8", "Teensyduino RawHID"];

const RESOURCE_BUSY_SUBSTRING: &str = "failed: Resource busy";

const SENDING_RESET_COMMAND_SUBSTRING: &str = "Sending reset command (with RTC)";

// TODO: Address this edge case
const REBOOT_DID_NOT_WORK_SUBSTRING: &str = "Reboot didn't work, press button manually";

fn path_to_str(path: &Path) -> String {
    path.to_str().unwrap_or_default().to_owned()
}

fn is_hex(path: &Path) -> bool {
    path.extension().and_then(|ext| ext.to_str()) == Some("hex")
}

// TODO: Refactor to represent upcoming mixer device in addition to M8.
#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum DeviceType {
    HEADLESS,
    MODEL01,
    MODEL02,
    UNKNOWN,
}

// Bricked/reset Teensy (MicroMod) shows up as:

// {
// 	"action": "add",
// 	"tag": "14908930-Teensy",
// 	"serial": "14908930",
// 	"description": "Teensyduino RawHID",
// 	"model": "Teensy MicroMod",
// 	"location": "usb-1-1",
// 	"capabilities": ["unique", "run", "rtc", "reboot", "serial"],
// 	"interfaces": [
// 		[
// 			"RawHID",
// 			"IOService:/AppleARMPE/arm-io@10F00000/AppleT810xIO/usb-drd1@2280000/AppleT8103USBXHCI@01000000/usb-drd1-port-hs@01100000/Teensyduino RawHID@01100000/IOUSBHostInterface@0/AppleUserUSBHostHIDDevice"
// 		],
// 		[
// 			"Seremu",
// 			"IOService:/AppleARMPE/arm-io@10F00000/AppleT810xIO/usb-drd1@2280000/AppleT8103USBXHCI@01000000/usb-drd1-port-hs@01100000/Teensyduino RawHID@01100000/IOUSBHostInterface@1/AppleUserUSBHostHIDDevice"
// 		]
// 	]
// }

pub fn determine_device_type(info: &TyCmdListEntry) -> DeviceType {
    if !matches!(info.description.as_str(), "M8" | "HalfKay") {
        return DeviceType::UNKNOWN;
    }

    match info.model.as_str() {
        // Firmware 6.3 introduced USB drive mode, and in doing so, Tim
        // seems to have updated the Teensy model field to report "Teensy"
        // instead of "Teensy MicroMod" for the MODEL:02.
        "Teensy MicroMod" | "Teensy" => DeviceType::MODEL02,
        "Teensy 4.0" => DeviceType::MODEL01,
        "Teensy 4.1" => DeviceType::HEADLESS,
        _ => DeviceType::UNKNOWN,
    }
}

pub trait DeviceTypeResolver {
    fn resolve(&self, description: &str) -> DeviceType;
}

pub struct CommandLineResolver;

impl DeviceTypeResolver for CommandLineResolver {
    fn resolve(&self, description: &str) -> DeviceType {
        match description {
            "Teensy MicroMod" => DeviceType::MODEL02,
            "Teensy 4.0" => DeviceType::MODEL01,
            "Teensy 4.1" => DeviceType::HEADLESS,
            _ => DeviceType::UNKNOWN,
        }
    }
}

pub struct SerialOutputResolver;

impl DeviceTypeResolver for SerialOutputResolver {
    fn resolve(&self, description: &str) -> DeviceType {
        if description.contains("M8") {
            DeviceType::MODEL01
        } else if description.contains("HalfKay") {
            DeviceType::MODEL02
        } else {
            DeviceType::UNKNOWN
        }
    }
}

impl DeviceType {
    pub fn new(description: &str, resolver: Box<dyn DeviceTypeResolver>) -> DeviceType {
        resolver.resolve(description)
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ConnectedDevice {
    // add   	This board was plugged in or was already there
    // change 	Something changed, maybe the board rebooted
    // miss 	This board is missing, either it was unplugged (remove) or it is changing mode
    // remove 	This board has been missing for some time, consider it removed
    pub action_history: Vec<String>,
    pub device_type: DeviceType,
    pub ty_cmd_info: TyCmdListEntry,
    pub updated_at: i64,
}

pub type ConnectedDeviceList = Vec<ConnectedDevice>;

#[derive(Debug, thiserror::Error)]
pub enum FirmwareStoreStatus {
    #[error("Cache directory initialization failure {0}")]
    CacheDirFailure(String),
    #[error("Temp directory initialization failure {0}")]
    TempDirFailure(String),
}

#[derive(Clone, Debug, Default)]
pub enum ArchiveSource {
    LocalPath(PathBuf),
    #[default]
    None,
    RemoteUrl(String),
}

fn setup_directory<F, G>(
    app_handle: &AppHandle,
    get_dir: F,
    update_state: G,
    error_variant: fn(String) -> FirmwareStoreStatus,
    dir_name: &str,
) -> Result<()>
where
    F: Fn() -> Result<PathBuf, anyhow::Error>,
    G: Fn(&mut AppStateData, Box<FilePath>),
{
    log::info!(
        "Setting up {} directory at {:?}",
        dir_name,
        get_dir().unwrap_or_default()
    );

    let dir = get_dir().map_err(|_| error_variant("<unknown>".to_string()))?;

    let scope = app_handle
        .try_fs_scope()
        .ok_or_else(|| error_variant(path_to_str(&dir)))?;

    scope
        .allow_directory(&dir, true)
        .map_err(|_| error_variant(path_to_str(&dir)))?;

    match std::fs::exists(&dir) {
        Ok(exists) => {
            if !exists {
                log::info!("Does not exist. Creating.");

                std::fs::create_dir_all(&dir).map_err(|_| error_variant(path_to_str(&dir)))?;
            }

            let state = app_handle.state::<AppState>();

            {
                let mut state_guard = state.blocking_lock();
                update_state(&mut state_guard, Box::new(FilePath::Path(dir.clone())));
            }

            log::info!(
                "Created {} firmware store at {}",
                dir_name,
                path_to_str(&dir)
            );

            Ok(())
        }
        Err(error) => Err(anyhow::Error::new(error)),
    }
}

fn load_firmware_info_cache(app_handle: &AppHandle) -> Result<()> {
    setup_directory(
        app_handle,
        || match app_handle.path().app_cache_dir() {
            Ok(cache_dir) => Ok(cache_dir),
            Err(error) => Err(anyhow::Error::new(error)),
        },
        |state_guard, dir| {
            state_guard.cache_dir = Some(dir);
        },
        FirmwareStoreStatus::CacheDirFailure,
        "cache",
    )
}

fn setup_temp_download_dir(app_handle: &AppHandle) -> Result<()> {
    setup_directory(
        app_handle,
        || match app_handle.path().temp_dir() {
            Ok(temp_dir) => {
                let mut with_extension = temp_dir.clone();

                with_extension.set_extension("app");

                Ok(temp_dir)
            }
            Err(error) => Err(anyhow::Error::new(error)),
        },
        |state_guard, dir| {
            state_guard.temp_dir = Some(dir);
        },
        FirmwareStoreStatus::TempDirFailure,
        "temp",
    )
}

async fn extract_firmware_to_cache(
    app_handle: &AppHandle,
    file_path: FilePath,
    filter: Option<fn(&Path) -> bool>,
) -> Result<Vec<PathBuf>> {
    log::info!("In extract_firmware_to_cache");
    log::info!("path is {}", file_path);

    let mut cache_paths: Vec<PathBuf> = Vec::new();

    let file = FsExt::fs(app_handle)
        .open::<FilePath>(file_path, OpenOptions::new().read(true).to_owned())
        .map_err(|e| {
            eprintln!("Failed to open file: {e}");
            e
        })?;

    let mut archive = ZipArchive::new(file)?;

    for i in 0..archive.len() {
        let mut archive_file = archive.by_index(i)?;
        let path = archive_file
            .enclosed_name()
            .ok_or_else(|| anyhow::Error::msg("Invalid path"))?;

        // Apply the filter if provided
        if let Some(filter_fn) = filter {
            if !filter_fn(&path) {
                continue;
            }
        }

        let state = app_handle.state::<AppState>();
        let state_guard = state.lock().await;

        if let Some(dir) = &state_guard.cache_dir {
            let cache_path = Path::new(dir.as_path().unwrap()).join(path.file_name().unwrap());
            let mut cache_file = FsExt::fs(app_handle).open::<FilePath>(
                FilePath::Path(cache_path.clone()),
                OpenOptions::new().create(true).write(true).to_owned(),
            )?;
            std::io::copy(&mut archive_file, &mut cache_file)?;
            cache_paths.push(cache_path);
        }
    }

    Ok(cache_paths)
}

async fn fetch_archive(app_handle: &AppHandle, source: ArchiveSource) -> Result<FilePath> {
    log::info!("In fetch_archive, given: {:?}", source);

    match source {
        ArchiveSource::LocalPath(path) => Ok(FilePath::Path(path)),
        ArchiveSource::None => Err(anyhow::Error::msg("No archive source provided")),
        ArchiveSource::RemoteUrl(url) => {
            log::info!("matched remote url {}", url);

            let state = app_handle.state::<AppState>();

            let mut state_guard = state.lock().await;

            log::info!("state lock guard acquired");

            let temp_dir = state_guard
                .temp_dir
                .clone()
                .ok_or_else(|| anyhow::Error::msg("Temp directory not set"))?;

            log::info!("temp directory is {}", temp_dir);

            let mut headers = HeaderMap::new();

            headers.insert("Accept", "application/vnd.github.raw+json".parse()?);
            headers.insert(USER_AGENT, "com.dirtywave.updater".parse()?);
            headers.insert("X-GitHub-Api-Version", "2022-11-28".parse()?);

            let client = reqwest::Client::new();

            let head = client.head(&url).headers(headers.clone()).send().await;

            state_guard.size = match head {
                Ok(response) => {
                    if let Some(content_length) = response.headers().get("content-length") {
                        if let Ok(size_str) = content_length.to_str() {
                            if let Ok(size) = size_str.parse::<u64>() {
                                log::info!(
                                    "File size: {} bytes ({:.2} MB)",
                                    size,
                                    size as f64 / 1_048_576.0
                                );
                                size
                            } else {
                                log::warn!("Could not parse content-length: {}", size_str);
                                0
                            }
                        } else {
                            0
                        }
                    } else {
                        log::warn!("No content-length header found");
                        0
                    }
                }
                Err(e) => {
                    log::error!("HEAD request failed: {}", e);
                    0
                }
            };

            let size = state_guard.size;

            let version = state_guard.version.clone();

            drop(state_guard);

            let temp_path = FilePath::Path(
                Path::new(temp_dir.as_path().unwrap()).join(format!("{}.zip", version)),
            );

            log::info!("temp path is {}", temp_path);

            let mut temp_file = FsExt::fs(app_handle).open::<FilePath>(
                temp_path.clone(),
                OpenOptions::new().create(true).write(true).to_owned(),
            )?;

            let stream = client.get(url).headers(headers).send().await;

            if let Err(error) = stream {
                log::info!("error downloading from GitHub/ opening stream");
                return Err(anyhow::Error::new(error));
            }

            let mut stream = stream.unwrap().bytes_stream();

            let mut bytes_downloaded: u32 = 0;

            let mut last_progress_update = std::time::Instant::now();

            const PROGRESS_UPDATE_INTERVAL: std::time::Duration =
                std::time::Duration::from_millis(100);

            while let Some(chunk) = stream.next().await {
                let bytes = chunk?;

                temp_file.write_all(&bytes)?;

                let chunk_size = u32::try_from(bytes.len())?;

                bytes_downloaded += chunk_size;

                let now = std::time::Instant::now();
                if now.duration_since(last_progress_update) >= PROGRESS_UPDATE_INTERVAL {
                    log::info!("Surfacing download progress {}", bytes_downloaded);

                    let mut state_guard = state.lock().await;

                    state_guard.flashing = Some(FlashingStatus::Downloading(DownloadStatus {
                        bytes_downloaded,
                        log: None,
                        size,
                        state: DownloadState::Downloading,
                    }));

                    let _ = state_guard.emit_device_state_update(app_handle);

                    drop(state_guard);

                    last_progress_update = now;
                }
            }

            log::info!("Download complete, returning OK {}", temp_path);

            let mut state_guard = state.lock().await;

            state_guard.flashing = Some(FlashingStatus::Downloading(DownloadStatus {
                bytes_downloaded,
                log: Some("Download complete".to_string()),
                size,
                state: DownloadState::Complete,
            }));

            let _ = state_guard.emit_device_state_update(app_handle);

            drop(state_guard);

            Ok(temp_path)
        }
    }
}

pub struct CachePath {
    pub device_type: DeviceType,
    pub path: PathBuf,
}

pub type CachePaths = Vec<CachePath>;

pub async fn download_firmware(app_handle: &AppHandle) -> Result<CachePaths> {
    log::info!("In download_firmware");
    let state = app_handle.state::<AppState>();
    let state_guard = state.lock().await;

    let source = state_guard.archive_source.clone();

    drop(state_guard);

    // Support both remote archives and local .zip/.hex files
    let filter_hex: Option<fn(&Path) -> bool> = Some(is_hex);

    let paths: Vec<PathBuf> = match source {
        ArchiveSource::LocalPath(p) => {
            log::info!("Fetching local path");
            if p.extension().and_then(|ext| ext.to_str()) == Some("hex") {
                vec![p]
            } else {
                let file_path = FilePath::Path(p);
                extract_firmware_to_cache(app_handle, file_path, filter_hex).await?
            }
        }
        ArchiveSource::RemoteUrl(_) => {
            log::info!("Fetching remote archive");
            let file_path = fetch_archive(app_handle, source).await?;
            extract_firmware_to_cache(app_handle, file_path, filter_hex).await?
        }
        ArchiveSource::None => {
            log::info!("No ArchiveSource");
            return Err(anyhow::Error::msg("No archive source provided"));
        }
    };

    log::info!("paths: {:?}", paths);

    let tagged_paths: CachePaths = paths
        .iter()
        .map(|path| CachePath {
            device_type: if path.to_str().unwrap_or("").contains("MODEL02") {
                DeviceType::MODEL02
            } else {
                DeviceType::MODEL01
            },
            path: path.to_path_buf(),
        })
        .collect();

    Ok(tagged_paths)
}

pub fn setup_firmware_store(app_handle: &AppHandle) -> Result<()> {
    load_firmware_info_cache(app_handle)?;
    setup_temp_download_dir(app_handle)?;

    Ok(())
}

pub fn start_firmware_download_handler(app_handle: Arc<AppHandle>) {
    let download_firmware_app_handle = app_handle.clone();
    let serial_probe_app_handle = app_handle.clone();

    tauri::async_runtime::spawn(async move {
        let state = serial_probe_app_handle.state::<AppState>();

        let state_guard = state.lock().await;

        let device = state_guard.device.clone();

        log::info!("Starting serial probe for device {:#?}", device);

        let interfaces = state_guard
            .device
            .as_ref()
            .map(|d| d.ty_cmd_info.interfaces.clone())
            .unwrap_or_default();

        drop(state_guard);

        log::info!("Interfaces {:?}", interfaces);

        if let Some(serial_interface) = interfaces
            .iter()
            .find(|interface| interface.first() == Some(&"Serial".to_string()))
        {
            if let Some(port) = serial_interface.get(1) {
                log::info!("Communicating on interface {:?}", port);
                serial::get_m8_details(port.as_str());
            }
        }
    });

    tauri::async_runtime::spawn(async move {
        log::info!("Starting firmware download");

        let state = download_firmware_app_handle.state::<AppState>();
        let state_guard = state.lock().await;

        let device = state_guard.device.clone();
        let version = state_guard.version.clone();

        drop(state_guard);

        let result = if let Some(device) = device {
            match download_firmware(&download_firmware_app_handle.clone()).await {
                Ok(firmware_paths) => {
                    let mut state_guard: tokio::sync::MutexGuard<'_, AppStateData> =
                        state.lock().await;

                    state_guard.flashing = Some(FlashingStatus::Updating(UpdateStatus {
                        log: Some("upload@status Verifying firmware matches device".to_string()),
                        state: UpdateState::Starting,
                    }));

                    let _ = state_guard.emit_device_state_update(&app_handle);

                    drop(state_guard);

                    match firmware_paths.iter().find(|cache_path| {
                        let path = cache_path.path.to_str().unwrap_or_default();

                        let device_type = &format!("{:?}", device.device_type);

                        match device.device_type {
                            DeviceType::MODEL02 => path.contains(device_type),
                            DeviceType::MODEL01 => {
                                // Before the introduction of MODEL:02, the firmware files
                                // did not specify the supported model in their filenames.
                                path.contains(device_type)
                                    || (!path.contains(&format!("{:?}", DeviceType::MODEL02))
                                        && !path.contains(&format!("{:?}", DeviceType::HEADLESS)))
                            }
                            DeviceType::HEADLESS | DeviceType::UNKNOWN => false,
                        }
                    }) {
                        Some(cache_path) => {
                            let sidecar = download_firmware_app_handle
                                .shell()
                                .sidecar("tycmd")
                                .unwrap()
                                .set_raw_out(true)
                                .args([
                                    "upload",
                                    cache_path.path.to_str().unwrap_or_default(),
                                    "--board",
                                    &device.ty_cmd_info.tag,
                                ]);

                            let (mut rx, _child) = sidecar.spawn().expect("Failed to spawn tycmd");

                            let mut error: Option<Error> = None;

                            while let Some(event) = rx.recv().await {
                                if let CommandEvent::Stdout(line) = event.clone() {
                                    let output = String::from_utf8(line).unwrap();
                                    log::info!("{}", output);

                                    let state = download_firmware_app_handle.state::<AppState>();

                                    let mut state_guard = state.lock().await;

                                    let next_state =
                                        if output.contains(SENDING_RESET_COMMAND_SUBSTRING) {
                                            UpdateState::Finalizing
                                        } else {
                                            UpdateState::Updating
                                        };

                                    state_guard.flashing =
                                        Some(FlashingStatus::Updating(UpdateStatus {
                                            log: Some(output.clone()),
                                            state: next_state,
                                        }));

                                    let _ = state_guard.emit_device_state_update(&app_handle);

                                    drop(state_guard);
                                }

                                if let CommandEvent::Stderr(line) = event.clone() {
                                    let output = String::from_utf8(line).unwrap();
                                    log::info!("{}", output);

                                    error = Some(anyhow::Error::msg(
                                        if output.contains(RESOURCE_BUSY_SUBSTRING) {
                                            "upload@status Device busy. Using remote display?"
                                                .to_string()
                                        } else {
                                            output
                                        },
                                    ));

                                    break;
                                }

                                if let CommandEvent::Error(line) = event.clone() {
                                    log::info!("{}", line);

                                    error = Some(anyhow::Error::msg(line));

                                    break;
                                }
                            }

                            log::info!(
                                "Done receiving data from tycmd child process (firmware.rs)"
                            );

                            match error {
                                Some(e) => Err(e),
                                None => {
                                    let state = download_firmware_app_handle.state::<AppState>();
                                    let mut state_guard = state.lock().await;

                                    state_guard.flashing = None;

                                    let _ = state_guard.emit_device_state_update(&app_handle);

                                    drop(state_guard);

                                    Ok(())
                                }
                            }
                        }
                        None => Err(anyhow::Error::msg(
                            format!(
                                "upload@status No {:?} variant found for version {}",
                                device.device_type, version
                            )
                            .to_string(),
                        )),
                    }
                }
                // TODO: Handle "Failed to download firmware: invalid Zip archive: Invalid local file header"
                Err(e) => Err(anyhow::Error::msg(format!(
                    "upload@status Failed to download firmware: {:?}",
                    e
                ))),
            }
        } else {
            Err(anyhow::Error::msg(
                "upload@status Unable to fetch details for selected device",
            ))
        };

        if let Err(e) = result {
            let state = download_firmware_app_handle.state::<AppState>();

            let mut state_guard = state.lock().await;

            state_guard.flashing = Some(FlashingStatus::Updating(UpdateStatus {
                log: Some(e.to_string()),
                state: UpdateState::Error,
            }));

            let _ = state_guard.emit_device_state_update(&app_handle);

            drop(state_guard);
        }
    });
}

#[async_trait]
impl FirmwareUpdater for TyCmdUpdater {
    async fn update_firmware(
        &self,
        firmware_path: &str,
        board_tag: &str,
        on_progress: Box<dyn Fn(UpdateStatus) + Send + Sync>,
    ) -> Result<(), anyhow::Error> {
        let sidecar = self
            .app_handle
            .shell()
            .sidecar("tycmd")
            .unwrap()
            .set_raw_out(true)
            .args(["update", firmware_path, "--board", board_tag]);

        let (mut rx, _child) = sidecar.spawn().expect("Failed to spawn tycmd");

        let mut error: Option<anyhow::Error> = None;

        while let Some(event) = rx.recv().await {
            match event {
                CommandEvent::Stdout(line) => {
                    let output = String::from_utf8_lossy(&line).to_string();
                    let state = if output.contains(SENDING_RESET_COMMAND_SUBSTRING) {
                        UpdateState::Finalizing
                    } else {
                        UpdateState::Updating
                    };

                    on_progress(UpdateStatus {
                        log: Some(output),
                        state,
                    });
                }
                CommandEvent::Stderr(line) => {
                    let output = String::from_utf8_lossy(&line).to_string();

                    error = Some(anyhow::Error::msg(output));

                    break;
                }
                CommandEvent::Error(line) => {
                    error = Some(anyhow::Error::msg(line));

                    break;
                }
                _ => {}
            }
        }

        match error {
            Some(e) => Err(e),
            None => Ok(()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::serial::tycmd::TyCmdListEntry;

    fn entry(description: &str, model: &str) -> TyCmdListEntry {
        TyCmdListEntry {
            action: "add".into(),
            capabilities: vec![],
            description: description.into(),
            interfaces: vec![],
            location: "usb-1-1".into(),
            model: model.into(),
            serial: "123".into(),
            tag: "t".into(),
        }
    }

    #[test]
    fn determine_device_type_maps_models() {
        // Non-M8/HalfKay -> UNKNOWN
        assert_eq!(
            determine_device_type(&entry("Foo", "Teensy 4.0")),
            DeviceType::UNKNOWN
        );

        // Allowed descriptions map by model
        assert_eq!(
            determine_device_type(&entry("M8", "Teensy 4.0")),
            DeviceType::MODEL01
        );
        assert_eq!(
            determine_device_type(&entry("M8", "Teensy 4.1")),
            DeviceType::HEADLESS
        );
        assert_eq!(
            determine_device_type(&entry("M8", "Teensy MicroMod")),
            DeviceType::MODEL02
        );

        assert_eq!(
            determine_device_type(&entry("HalfKay", "Teensy 4.0")),
            DeviceType::MODEL01
        );
    }

    #[test]
    fn device_type_resolvers_work() {
        // CommandLineResolver
        assert_eq!(
            DeviceType::new("Teensy 4.0", Box::new(CommandLineResolver)),
            DeviceType::MODEL01
        );

        // SerialOutputResolver (instantiate anew for each move)
        assert_eq!(
            DeviceType::new("M8 detected", Box::new(SerialOutputResolver)),
            DeviceType::MODEL01
        );
        assert_eq!(
            DeviceType::new("HalfKay bootloader", Box::new(SerialOutputResolver)),
            DeviceType::MODEL02
        );
        assert_eq!(
            DeviceType::new("Other", Box::new(SerialOutputResolver)),
            DeviceType::UNKNOWN
        );
    }
}
