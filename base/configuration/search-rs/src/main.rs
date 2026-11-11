//! ElvonOS desktop search index.
//!
//! Scans the standard XDG user directories once and prints a compact JSON
//! array.  The Qt desktop keeps the result in memory and filters it on every
//! keystroke.  Rust makes the one-time traversal cheap and keeps the QML/C++
//! UI thread free.
//!
//! Usage: elvonos-search-index [--json]

use std::env;
use std::fs;
use std::path::{Path, PathBuf};

const MAX_FILES: usize = 4000;
const MAX_DEPTH: usize = 10;

#[derive(Debug)]
struct Entry {
    name: String,
    path: String,
}

fn home() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/"))
}

fn user_dir(env_key: &str, fallback: &str) -> PathBuf {
    if let Some(value) = env::var_os(env_key) {
        let path = PathBuf::from(value);
        if path.is_dir() {
            return path;
        }
    }
    home().join(fallback)
}

fn roots() -> Vec<PathBuf> {
    vec![
        user_dir("XDG_DESKTOP_DIR", "Desktop"),
        user_dir("XDG_DOCUMENTS_DIR", "Documents"),
        user_dir("XDG_DOWNLOAD_DIR", "Downloads"),
        user_dir("XDG_PICTURES_DIR", "Pictures"),
        user_dir("XDG_MUSIC_DIR", "Music"),
        user_dir("XDG_VIDEOS_DIR", "Videos"),
    ]
}

fn is_hidden(name: &str) -> bool {
    name.starts_with('.')
}

fn scan(root: &Path, entries: &mut Vec<Entry>) {
    let mut stack: Vec<(PathBuf, usize)> = vec![(root.to_path_buf(), 0)];
    while let Some((directory, depth)) = stack.pop() {
        if depth > MAX_DEPTH || entries.len() >= MAX_FILES {
            return;
        }
        let Ok(read_dir) = fs::read_dir(&directory) else {
            continue;
        };
        for item in read_dir.flatten() {
            if entries.len() >= MAX_FILES {
                return;
            }
            let name = item.file_name();
            let Some(name) = name.to_str() else {
                continue;
            };
            if is_hidden(name) {
                continue;
            }
            let path = item.path();
            let Ok(file_type) = item.file_type() else {
                continue;
            };
            if file_type.is_dir() {
                stack.push((path, depth + 1));
                continue;
            }
            if !file_type.is_file() {
                continue;
            }
            if name.ends_with(".desktop") {
                continue;
            }
            entries.push(Entry {
                name: name.to_string(),
                path: path.to_string_lossy().into_owned(),
            });
        }
    }
}

fn json_escape(value: &str) -> String {
    let mut out = String::with_capacity(value.len() + 8);
    for ch in value.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out
}

fn main() {
    let mut entries = Vec::new();
    for root in roots() {
        if root.is_dir() {
            scan(&root, &mut entries);
        }
    }
    entries.sort_by(|a, b| a.path.cmp(&b.path));

    let mut output = String::from("[");
    for (index, entry) in entries.iter().enumerate() {
        if index > 0 {
            output.push(',');
        }
        output.push_str("{\"name\":\"");
        output.push_str(&json_escape(&entry.name));
        output.push_str("\",\"path\":\"");
        output.push_str(&json_escape(&entry.path));
        output.push_str("\"}");
    }
    output.push(']');
    println!("{}", output);
}
