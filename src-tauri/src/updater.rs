#[cfg(desktop)]
pub mod app_updates {
    use serde::Serialize;
    use std::sync::Mutex;
    use tauri::{ipc::Channel, State};
    use tauri_plugin_updater::{Update, UpdaterExt};

    #[derive(Debug, thiserror::Error)]
    pub enum Error {
        #[error(transparent)]
        Updater(#[from] tauri_plugin_updater::Error),
        #[error("there is no pending update")]
        NoPendingUpdate,
    }

    impl Serialize for Error {
        fn serialize<S>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error>
        where
            S: serde::Serializer,
        {
            serializer.serialize_str(self.to_string().as_str())
        }
    }

    type Result<T> = std::result::Result<T, Error>;

    #[derive(Clone, Serialize)]
    #[serde(tag = "event", content = "data")]
    pub enum DownloadEvent {
        #[serde(rename_all = "camelCase")]
        Started {
            content_length: Option<u64>,
        },
        #[serde(rename_all = "camelCase")]
        Progress {
            chunk_length: usize,
        },
        Finished,
    }

    #[derive(Serialize)]
    #[serde(rename_all = "camelCase")]
    pub struct UpdateMetadata {
        version: String,
        current_version: String,
    }

    #[tauri::command]
    pub async fn install_update(
        pending_update: State<'_, PendingUpdate>,
        on_event: Channel<DownloadEvent>,
    ) -> Result<()> {
        let Some(update) = pending_update.0.lock().unwrap().take() else {
            return Err(Error::NoPendingUpdate);
        };

        let mut started = false;

        update
            .download_and_install(
                |chunk_length, content_length| {
                    if !started {
                        let _ = on_event.send(DownloadEvent::Started { content_length });
                        started = true;
                    }

                    let _ = on_event.send(DownloadEvent::Progress { chunk_length });
                },
                || {
                    let _ = on_event.send(DownloadEvent::Finished);
                },
            )
            .await?;

        Ok(())
    }

    pub struct PendingUpdate(Mutex<Option<Update>>);

    pub async fn update(app: tauri::AppHandle) -> tauri_plugin_updater::Result<()> {
        log::info!("In updater::update");

        match app.updater()?.check().await {
            Ok(Some(update)) => {
                log::info!("update found: {}", update.raw_json);

                let mut downloaded = 0;

                // alternatively we could also call update.download() and update.install() separately
                update
                    .download_and_install(
                        |chunk_length, _content_length| {
                            downloaded += chunk_length;
                            // log::info!("downloaded {downloaded} from {content_length:?}");
                        },
                        || {
                            log::info!("download finished");
                        },
                    )
                    .await?;

                log::info!("update installed");
                app.restart();
            }
            Ok(None) => {
                log::info!("no update found");
            }
            Err(e) => {
                log::error!("update check failed: {:?}", e);
            }
        }

        Ok(())
    }
}
