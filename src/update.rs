//! Update check for the About window: asks the GitHub API for the latest stable
//! release and compares it with the running version. Uses `curl` (already a
//! prerequisite of install.sh) so no HTTP/TLS dependency is needed.

use std::process::Command;

const LATEST_RELEASE_API: &str =
    "https://api.github.com/repos/OleksiyM/GnomeLngSwitcher/releases/latest";

pub const RELEASES_URL: &str = "https://github.com/OleksiyM/GnomeLngSwitcher/releases/latest";

#[derive(Debug, PartialEq, Eq)]
pub enum UpdateStatus {
    UpToDate,
    Available(String),
    Unknown,
}

/// Parses `X.Y.Z` or `vX.Y.Z` into a comparable tuple.
fn parse_version(s: &str) -> Option<(u64, u64, u64)> {
    let mut parts = s.trim().trim_start_matches('v').split('.');
    let major = parts.next()?.parse().ok()?;
    let minor = parts.next()?.parse().ok()?;
    let patch = parts.next()?.parse().ok()?;
    if parts.next().is_some() {
        return None;
    }
    Some((major, minor, patch))
}

fn compare(latest_tag: &str, current: &str) -> UpdateStatus {
    match (parse_version(latest_tag), parse_version(current)) {
        (Some(latest), Some(cur)) if latest > cur => {
            UpdateStatus::Available(latest_tag.trim().to_string())
        }
        (Some(_), Some(_)) => UpdateStatus::UpToDate,
        _ => UpdateStatus::Unknown,
    }
}

fn fetch_latest_tag() -> Option<String> {
    let output = Command::new("curl")
        .args([
            "--fail",
            "--silent",
            "--location",
            "--max-time",
            "8",
            "--proto",
            "=https",
            "-H",
            "Accept: application/vnd.github+json",
            "-A",
            concat!("GnomeLngSwitcher/", env!("CARGO_PKG_VERSION")),
            LATEST_RELEASE_API,
        ])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let json: serde_json::Value = serde_json::from_slice(&output.stdout).ok()?;
    json.get("tag_name")?.as_str().map(str::to_string)
}

/// Blocking network call; run it off the GTK main thread.
pub fn check_for_update() -> UpdateStatus {
    match fetch_latest_tag() {
        Some(tag) => compare(&tag, env!("CARGO_PKG_VERSION")),
        None => UpdateStatus::Unknown,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn newer_release_is_reported() {
        assert_eq!(
            compare("v1.0.0", "0.9.9"),
            UpdateStatus::Available("v1.0.0".into())
        );
        assert_eq!(
            compare("v0.10.0", "0.9.0"),
            UpdateStatus::Available("v0.10.0".into())
        );
    }

    #[test]
    fn same_or_older_release_is_up_to_date() {
        assert_eq!(compare("v1.0.0", "1.0.0"), UpdateStatus::UpToDate);
        assert_eq!(compare("v0.9.0", "1.0.0"), UpdateStatus::UpToDate);
    }

    #[test]
    fn garbage_tag_is_unknown() {
        assert_eq!(compare("nightly", "1.0.0"), UpdateStatus::Unknown);
        assert_eq!(compare("v1.0", "1.0.0"), UpdateStatus::Unknown);
    }
}
