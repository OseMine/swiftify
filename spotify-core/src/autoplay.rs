//! the songs spotify suggests once a queue runs out, read through the session.
//!
//! the result is json shaped like the artist top tracks response, so the front
//! end reads it with the same parser.

use std::collections::HashSet;

use librespot::{core::Session, protocol::autoplay_context_request::AutoplayContextRequest};
use serde::Serialize;

use crate::playlist::{TrackPayload, track_metadata};

/// how many of what just played spotify is told about. its own players send a
/// handful, and the suggestions get worse when the list is long
const RECENT_TRACK_COUNT: usize = 8;

pub async fn autoplay_tracks_json(
    session: &Session,
    context_uri: &str,
    recent_tracks: &[String],
) -> Result<String, String> {
    let request = AutoplayContextRequest {
        context_uri: Some(context_uri.to_owned()),
        recent_track_uri: recent_tracks
            .iter()
            .rev()
            .take(RECENT_TRACK_COUNT)
            .rev()
            .cloned()
            .collect(),
        ..Default::default()
    };
    let context = session
        .spclient()
        .get_autoplay_context(&request)
        .await
        .map_err(|error| format!("Spotify would not suggest what to play next: {error}"))?;

    let mut seen = HashSet::new();
    let uris: Vec<String> = context
        .pages
        .iter()
        .flat_map(|page| page.tracks.iter())
        .filter_map(|track| track.uri.clone())
        .filter(|uri| uri.starts_with("spotify:track:"))
        .filter(|uri| seen.insert(uri.clone()))
        .collect();
    if uris.is_empty() {
        return Err("Spotify had nothing to suggest".to_owned());
    }

    let found = track_metadata(session, &uris).await?;
    let tracks: Vec<TrackPayload> = uris
        .iter()
        .filter_map(|uri| found.get(uri).cloned())
        .collect();
    serde_json::to_string(&TracksPayload { tracks })
        .map_err(|error| format!("failed to encode the suggestions: {error}"))
}

#[derive(Serialize)]
struct TracksPayload {
    tracks: Vec<TrackPayload>,
}
