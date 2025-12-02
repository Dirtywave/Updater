use std::env;
use std::sync::Arc;

use anyhow::Result;
use firmware::start_firmware_download_handler;
use serial::provider::{DeviceProvider, TycmdProvider};
use tauri::{App, AppHandle, Manager};
use tauri_plugin_opener::{self, reveal_item_in_dir};

use crate::{
    events::frontend_events::{self, FrontendEvent},
    state::{AppState, AppStateData},
};

pub mod events;
pub mod firmware;
pub mod serial;
pub mod state;
pub mod updater;

fn setup(app: &mut App) -> Result<(), Box<dyn std::error::Error>> {
    let app_handle = app.handle();

    log::info!(
        "{}",
        app_handle
            .path()
            .app_config_dir()
            .unwrap()
            .to_str()
            .unwrap()
    );

    app_handle.manage(AppState::new(AppStateData::default()));

    #[cfg(not(debug_assertions))]
    {
        tauri::async_runtime::spawn(async move {
            crate::updater::app_updates::update(updater_app_handle.clone())
                .await
                .unwrap();
        });
    }

    firmware::setup_firmware_store(app_handle)?;

    #[cfg(any(windows, target_os = "linux"))]
    {
        use tauri_plugin_deep_link::DeepLinkExt;
        app.deep_link().register_all()?;
    }

    setup_event_listeners(Arc::new(app_handle.clone()));

    Ok(())
}

fn setup_event_listeners(app_handle: Arc<AppHandle>) {
    log::info!("Setting up event listeners");
    let start_firmware_download_app_handle = app_handle.clone();

    frontend_events::StartFirmwareDownload::listen(
        &start_firmware_download_app_handle.clone(),
        move |_, _payload| {
            log::info!("In startfirmwaredownload callback");
            start_firmware_download_handler(start_firmware_download_app_handle.clone());
        },
    );

    let version_selected_app_handle = app_handle.clone();

    frontend_events::VersionSelected::listen(
        &version_selected_app_handle.clone(),
        move |_event, payload| {
            log::info!(
                "User created: Version={:?}, DownloadLink={}",
                payload.version,
                payload.path
            );

            let state_set_app_handle = version_selected_app_handle.clone();

            tauri::async_runtime::spawn(async move {
                use crate::firmware::ArchiveSource;
                let state = state_set_app_handle.state::<AppState>();

                let mut state_guard = state.lock().await;

                // Determine archive source from payload.path
                if payload.path.starts_with("http://") || payload.path.starts_with("https://") {
                    state_guard.archive_source = ArchiveSource::RemoteUrl(payload.path.clone());
                } else {
                    state_guard.archive_source =
                        ArchiveSource::LocalPath(std::path::PathBuf::from(payload.path.clone()));

                    state_guard.size = 0;
                }

                state_guard.version = payload.version.clone().unwrap_or_default();
            });
        },
    );

    let show_logs_app_handle = app_handle.clone();

    frontend_events::ShowLogs::listen(&show_logs_app_handle.clone(), move |_event, _| {
        log::info!("Showing logs");

        if let Ok(log_dir) = show_logs_app_handle.path().app_log_dir() {
            let _ = reveal_item_in_dir(log_dir);
        }
    });

    let frontend_loaded_app_handle = app_handle.clone();

    frontend_events::FrontendLoaded::listen(
        &frontend_loaded_app_handle.clone(),
        move |_event, _| {
            let provider = TycmdProvider;

            provider.start(&frontend_loaded_app_handle.clone());
        },
    );
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let mut builder = tauri::Builder::default();

    // Single instance must be the first plugin registered to integrate with deep-link
    #[cfg(desktop)]
    {
        builder = builder.plugin(tauri_plugin_single_instance::init(|app, argv, _cwd| {
          println!("a new app instance was opened with {argv:?} and the deep link event was already triggered");
          // when defining deep link schemes at runtime, you must also check `argv` here
            if let Some(main_window) = app.get_webview_window("main") {
                if let Err(e) = main_window.set_focus() {
                    log::error!("Failed to set focus to main window: {}", e);
                }

                // set transparent title bar and background color only when building for macOS
                #[cfg(target_os = "macos")]
                {
                    if let Err(err) =
                        main_window.set_title_bar_style(tauri::TitleBarStyle::Transparent)
                    {
                        log::info!("Error setting title bar transparency {:?}", err);
                    }
                }
            } else {
                log::warn!("Main window not found");
            }
        }));
    }

    // https://docs.crabnebula.dev/devtools/troubleshoot/log-plugins/
    // Note: If you’re running CrabNebula DevTools next to another tracing/log plugin or crate,
    // DevTools will prevent any other logger from being initialized; indicative error:
    // Error while running Tauri application:
    // PluginInitialization("log", "attempted to set a logger after the logging system was already initialized")
    #[cfg(debug_assertions)]
    {
        builder = builder.plugin(tauri_plugin_devtools::init());
    }

    builder = builder
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_store::Builder::default().build())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_deep_link::init());

    let pinia_builder = tauri_plugin_pinia::Builder::new()
        .save_denylist(["installation", "serial-port-info"])
        .sync_denylist(["firmware", "installation", "serial-port-info"]);

    let pinia_builder = if let Ok(path) = env::var("PINIA_STORE_PATH") {
        pinia_builder.path(path)
    } else {
        pinia_builder
    };

    builder = builder.plugin(pinia_builder.build());

    #[cfg(desktop)]
    {
        builder = builder
            .plugin(tauri_plugin_updater::Builder::new().build())
            .plugin(tauri_plugin_window_state::Builder::default().build());
    }

    // TODO: More modern way of instantiating application looks like:
    // .run(tauri::generate_context!())
    // .expect("error while running tauri application");

    if let Err(e) = builder.setup(setup).run(tauri::generate_context!()) {
        eprintln!("Error while running Tauri application: {e:?}");

        log::error!("Error while running Tauri application: {}", e);
    }
}
