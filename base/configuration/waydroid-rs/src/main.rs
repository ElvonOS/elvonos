// ElvonOS Waydroid integration
//
// A dependency-free Rust replacement for the shell/Python helpers that used to
// glue Waydroid into ElvonOS.  It manages the container/session, installs APKs
// natively through the Android package manager, synchronises Android apps into
// the Win8DE application list and reports machine readable status.
//
// Build: rustc -O src/main.rs -o elvonos-waydroid

use dbus::blocking::Connection;
use std::collections::{BTreeMap, HashMap, HashSet};
use std::env;
use std::fs;
use std::io::{self, Write};
use std::os::unix::fs::MetadataExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Output, Stdio};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

const VERSION: &str = "1.1.0";
const CONTAINER_UNIT: &str = "waydroid-container.service";
const LXC_PATH: &str = "/var/lib/waydroid/lxc";
const LXC_NAME: &str = "waydroid";
const APPS_DIR: &str = "/usr/share/elvonos/waydroid/apps";
const AURORA_ICON: &str = "/usr/share/icons/elvonos/metro/aurora-store.png";
const ANDROID_MARKER: &str = "X-ElvonOS-Android=true";

const LOCALES: [(&str, &str); 15] = [
    ("en", ""),
    ("de", "de"),
    ("fr", "fr"),
    ("es", "es"),
    ("it", "it"),
    ("pt", "pt"),
    ("nl", "nl"),
    ("pl", "pl"),
    ("ru", "ru"),
    ("tr", "tr"),
    ("uk", "uk"),
    ("cs", "cs"),
    ("sv", "sv"),
    ("zh", "zh_CN"),
    ("ja", "ja"),
];

const GENERIC_NAMES: [(&str, &str); 15] = [
    ("en", "Android App"),
    ("de", "Android-App"),
    ("fr", "Application Android"),
    ("es", "Aplicación Android"),
    ("it", "App Android"),
    ("pt", "Aplicativo Android"),
    ("nl", "Android-app"),
    ("pl", "Aplikacja Android"),
    ("ru", "Приложение Android"),
    ("tr", "Android Uygulaması"),
    ("uk", "Застосунок Android"),
    ("cs", "Aplikace Android"),
    ("sv", "Android-app"),
    ("zh", "Android 应用"),
    ("ja", "Android アプリ"),
];

const COMMENTS: [(&str, &str); 15] = [
    ("en", "Android app running in Waydroid"),
    ("de", "Android-App in Waydroid"),
    ("fr", "Application Android exécutée dans Waydroid"),
    ("es", "Aplicación Android ejecutada en Waydroid"),
    ("it", "App Android in esecuzione in Waydroid"),
    ("pt", "Aplicativo Android em execução no Waydroid"),
    ("nl", "Android-app die in Waydroid draait"),
    ("pl", "Aplikacja Android uruchomiona w Waydroid"),
    ("ru", "Приложение Android в Waydroid"),
    ("tr", "Waydroid'de çalışan Android uygulaması"),
    ("uk", "Застосунок Android у Waydroid"),
    ("cs", "Aplikace Android ve Waydroidu"),
    ("sv", "Android-app som körs i Waydroid"),
    ("zh", "在 Waydroid 中运行的 Android 应用"),
    ("ja", "Waydroid で実行中の Android アプリ"),
];

fn main() {
    let argv: Vec<String> = env::args().collect();
    let program = argv
        .first()
        .map(|value| {
            Path::new(value)
                .file_name()
                .and_then(|name| name.to_str())
                .unwrap_or("elvonos-waydroid")
                .to_string()
        })
        .unwrap_or_else(|| "elvonos-waydroid".into());

    let code = match program.as_str() {
        "elvonos-waydroid-sync" => cmd_sync(),
        "elvonos-waydroid-install-apk" => cmd_install(&argv[1..]),
        "elvonos-waydroid-apk-entry" => cmd_apk_entry(&argv[1..]),
        "elvonos-waydroid-apps.sh" | "elvonos-waydroid-apps" => cmd_apps(),
        _ => dispatch(&argv),
    };
    std::process::exit(code);
}

fn dispatch(argv: &[String]) -> i32 {
    let command = argv.get(1).map(|value| value.as_str()).unwrap_or("launch");
    match command {
        "launch" => cmd_launch(argv.get(2).map(|value| value.as_str())),
        "start" => cmd_start(),
        "session" => cmd_session(),
        "stop" => cmd_stop(),
        "status" => cmd_status(argv.iter().any(|value| value == "--json")),
        "apps" | "bootstrap" => cmd_apps(),
        "list" | "ls" => cmd_list(argv.iter().any(|value| value == "--json")),
        "remove" | "uninstall" => cmd_remove(argv.get(2).map(|value| value.as_str())),
        "sync" | "refresh" => cmd_sync(),
        "install" => cmd_install(&argv[2..]),
        "apk-entry" => cmd_apk_entry(&argv[2..]),
        "doctor" | "check" => cmd_doctor(),
        "recover" => cmd_recover(),
        "daemon" | "watch" => cmd_daemon(argv.iter().any(|value| value == "--once")),
        "autostart" => cmd_autostart(&argv[2..]),
        "autostart-run" => cmd_autostart_run(),
        "config" => cmd_config(&argv[2..]),
        "graphics" => cmd_graphics(&argv[2..]),
        "storage" => cmd_storage(argv.iter().any(|value| value == "--json")),
        "restart" => cmd_restart(),
        "clear-data" => cmd_clear_data(argv.get(2).map(|value| value.as_str()).unwrap_or("")),
        "bridge" => cmd_bridge(&argv[2..]),
        "freeze" => cmd_freeze(false),
        "unfreeze" => cmd_freeze(true),
        "share" => cmd_share(&argv[2..].join(" ")),
        "open" => cmd_open(&PathBuf::from(argv.get(2).map(|value| value.as_str()).unwrap_or(""))),
        "backup" => cmd_backup(argv.get(2).map(|value| value.as_str())),
        "restore" => cmd_restore(argv.get(2).map(|value| value.as_str()).unwrap_or("")),
        "multiwindow" => cmd_multiwindow(&argv[2..]),
        "version" | "--version" | "-V" => {
            println!("elvonos-waydroid {}", VERSION);
            0
        }
        "help" | "--help" | "-h" => {
            help();
            0
        }
        other if other.starts_with('-') => {
            eprintln!("Unknown option: {}", other);
            help();
            2
        }
        package => cmd_launch(Some(package)),
    }
}

fn help() {
    println!(
        "ElvonOS Waydroid integration {}\n\
\n\
Usage:\n\
  elvonos-waydroid [PACKAGE]        Start Waydroid and launch an Android app\n\
  elvonos-waydroid start            Start container, session and Android\n\
  elvonos-waydroid session          Native session service (internal)\n\
  elvonos-waydroid stop             Stop the session and container\n\
  elvonos-waydroid status [--json]  Show container, session and app state\n\
  elvonos-waydroid sync             Refresh Android apps in the Start menu\n\
  elvonos-waydroid list [--json]    List installed Android apps\n\
  elvonos-waydroid install [APK…]   Install APKs (file chooser when omitted)\n\
  elvonos-waydroid remove PACKAGE   Uninstall an Android app\n\
  elvonos-waydroid apps             Install bundled Aurora Store and microG\n\
  elvonos-waydroid apk-entry APK    Create one Start-menu entry from an APK\n\
  elvonos-waydroid doctor           Check the local Waydroid setup\n\
  elvonos-waydroid recover          Repair a stuck container/session\n\
  elvonos-waydroid daemon [--once]  Supervise session/apps in the background\n\
  elvonos-waydroid autostart on|off Start Waydroid at login\n\
  elvonos-waydroid config           Show configuration\n\
  elvonos-waydroid graphics MODE    auto|software|gpu rendering profile\n\
  elvonos-waydroid storage [--json] Show Android data usage and free space\n\
  elvonos-waydroid restart          Restart session and container\n\
  elvonos-waydroid clear-data PKG   Clear one Android app's data\n\
  elvonos-waydroid bridge start|stop|status  Clipboard/notification bridge\n\
  elvonos-waydroid freeze|unfreeze    Freeze or resume the Android container\n\
  elvonos-waydroid open FILE        Open a host file in an Android app\n\
  elvonos-waydroid share TEXT       Share text to Android apps\n\
  elvonos-waydroid backup [FILE]    Back up the Android data directory\n\
  elvonos-waydroid restore FILE     Restore an Android data backup\n\
  elvonos-waydroid multiwindow on|off  Multi-window mode (restart to apply)\n",
        VERSION
    );
}

// ---------------------------------------------------------------------------
// Paths and configuration

fn home() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/root"))
}

fn config_dir() -> PathBuf {
    env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home().join(".config"))
        .join("elvonos")
}

fn state_dir() -> PathBuf {
    env::var_os("XDG_STATE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home().join(".local/state"))
        .join("elvonos")
}

fn data_home() -> PathBuf {
    env::var_os("XDG_DATA_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home().join(".local/share"))
}

fn applications_dir() -> PathBuf {
    data_home().join("applications")
}

fn config_path() -> PathBuf {
    config_dir().join("waydroid.conf")
}

fn log_path() -> PathBuf {
    state_dir().join("waydroid.log")
}

fn state_path() -> PathBuf {
    state_dir().join("waydroid.json")
}

fn pause_path() -> PathBuf {
    state_dir().join("waydroid.pause")
}

fn daemon_pid_path() -> PathBuf {
    state_dir().join("waydroid-daemon.pid")
}

fn session_pid_path() -> PathBuf {
    state_dir().join("waydroid-session.pid")
}

fn session_map() -> HashMap<String, String> {
    let uid = current_uid();
    let gid = current_gid();
    let data_home = data_home();
    let runtime = env::var("XDG_RUNTIME_DIR")
        .unwrap_or_else(|_| format!("/run/user/{}", uid));
    let mut values = HashMap::new();
    values.insert(
        "user_name".into(),
        env::var("USER").unwrap_or_else(|_| "elvon".into()),
    );
    values.insert("user_id".into(), uid.to_string());
    values.insert("group_id".into(), gid.to_string());
    values.insert("host_user".into(), home().display().to_string());
    values.insert("pid".into(), std::process::id().to_string());
    values.insert("xdg_data_home".into(), data_home.display().to_string());
    values.insert("xdg_runtime_dir".into(), runtime.clone());
    values.insert(
        "wayland_display".into(),
        env::var("WAYLAND_DISPLAY").unwrap_or_else(|_| "wayland-0".into()),
    );
    values.insert(
        "pulse_runtime_path".into(),
        env::var("PULSE_RUNTIME_PATH")
            .unwrap_or_else(|_| format!("{}/pulse", runtime)),
    );
    values.insert("state".into(), "STOPPED".into());
    values.insert("lcd_density".into(), "0".into());
    values.insert("background_start".into(), "true".into());
    values.insert(
        "waydroid_user_state".into(),
        format!("{}/waydroid", data_home.display()),
    );
    values.insert(
        "waydroid_data".into(),
        format!("{}/waydroid/data", data_home.display()),
    );
    values
}

fn native_session_start() -> Result<(), String> {
    // The upstream session manager creates these directories before asking
    // the container service to start; LXC needs the data bind source.
    let session_root = data_home().join("waydroid");
    let session_data = session_root.join("data");
    fs::create_dir_all(&session_data).map_err(|error| error.to_string())?;
    let system = Connection::new_system().map_err(|error| error.to_string())?;
    let proxy = system.with_proxy(
        "id.waydro.Container",
        "/ContainerManager",
        Duration::from_secs(60),
    );
    let session = session_map();
    let _: () = proxy
        .method_call("id.waydro.ContainerManager", "Start", (session,))
        .map_err(|error| error.to_string())?;
    Ok(())
}

fn native_container_stop() -> bool {
    let Ok(system) = Connection::new_system() else {
        return false;
    };
    let proxy = system.with_proxy(
        "id.waydro.Container",
        "/ContainerManager",
        Duration::from_secs(30),
    );
    let result: Result<(), _> =
        proxy.method_call("id.waydro.ContainerManager", "Stop", (false,));
    result.is_ok()
}

fn daemon_running() -> bool {
    fs::read_to_string(daemon_pid_path())
        .ok()
        .and_then(|value| value.trim().parse::<u32>().ok())
        .map(|pid| Path::new(&format!("/proc/{}", pid)).exists())
        .unwrap_or(false)
}

fn load_config() -> HashMap<String, String> {
    let mut values = HashMap::new();
    values.insert("autostart".into(), "false".into());
    values.insert("notifications".into(), "true".into());
    if let Ok(text) = fs::read_to_string(config_path()) {
        for line in text.lines() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            if let Some((key, value)) = line.split_once('=') {
                values.insert(key.trim().to_string(), value.trim().to_string());
            }
        }
    }
    values
}

fn save_config(values: &HashMap<String, String>) -> io::Result<()> {
    fs::create_dir_all(config_dir())?;
    let mut keys: Vec<&String> = values.keys().collect();
    keys.sort();
    let mut text = String::from("# ElvonOS Waydroid configuration\n");
    for key in keys {
        text.push_str(key);
        text.push('=');
        text.push_str(values.get(key).map(String::as_str).unwrap_or(""));
        text.push('\n');
    }
    fs::write(config_path(), text)
}

fn language() -> String {
    if let Ok(text) = fs::read_to_string(config_dir().join("language")) {
        let code = text.trim();
        if !code.is_empty() {
            return code.to_string();
        }
    }
    let environment = env::var("LANG").unwrap_or_default();
    for (code, _) in LOCALES {
        if code != "en" && environment.starts_with(code) {
            return code.to_string();
        }
    }
    "en".into()
}

fn localized(key: &str) -> String {
    let lang = language();
    let table: &[(&str, &str); 15] = if key == "generic" {
        &GENERIC_NAMES
    } else {
        &COMMENTS
    };
    table
        .iter()
        .find(|(code, _)| *code == lang)
        .map(|(_, value)| value.to_string())
        .or_else(|| table.iter().find(|(code, _)| *code == "en").map(|(_, value)| value.to_string()))
        .unwrap_or_default()
}

fn timestamp() -> String {
    let seconds = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|value| value.as_secs() as i64)
        .unwrap_or(0);
    let days = seconds.div_euclid(86_400);
    let remainder = seconds.rem_euclid(86_400);
    let (year, month, day) = civil_from_days(days);
    format!(
        "{:04}-{:02}-{:02} {:02}:{:02}:{:02}Z",
        year,
        month,
        day,
        remainder / 3600,
        (remainder % 3600) / 60,
        remainder % 60
    )
}

fn civil_from_days(days: i64) -> (i64, i64, i64) {
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let year = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = doy - (153 * mp + 2) / 5 + 1;
    let month = mp + if mp < 10 { 3 } else { -9 };
    (year + if month <= 2 { 1 } else { 0 }, month, day)
}

fn log(message: &str) {
    let path = log_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Ok(metadata) = fs::metadata(&path) {
        if metadata.len() > 512 * 1024 {
            let _ = fs::rename(&path, path.with_extension("log.1"));
        }
    }
    if let Ok(mut file) = fs::OpenOptions::new().create(true).append(true).open(&path) {
        let _ = writeln!(file, "[{}] {}", timestamp(), message);
    }
}

fn message(key: &str) -> String {
    let german = language() == "de";
    let value = match (german, key) {
        (true, "starting") => "Waydroid wird gestartet. Der erste Start kann einige Minuten dauern.",
        (true, "ready") => "Waydroid ist bereit.",
        (true, "container-failed") => "Der Waydroid-Container konnte nicht gestartet werden.",
        (true, "session-failed") => "Die Waydroid-Sitzung konnte nicht gestartet werden.",
        (true, "boot-failed") => "Android wurde nicht rechtzeitig fertig gestartet.",
        (true, "not-ready") => "Waydroid ist nicht bereit; es wurde kein APK installiert.",
        (false, "starting") => "Waydroid is starting. The first start can take a few minutes.",
        (false, "ready") => "Waydroid is ready.",
        (false, "container-failed") => "The Waydroid container could not be started.",
        (false, "session-failed") => "The Waydroid session could not be started.",
        (false, "boot-failed") => "Android did not finish booting in time.",
        (false, "not-ready") => "Waydroid is not ready; no APK was installed.",
        _ => return key.to_string(),
    };
    value.to_string()
}

struct InstanceLock {
    path: PathBuf,
}

impl Drop for InstanceLock {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.path);
    }
}

fn try_lock() -> Option<InstanceLock> {
    let path = state_dir().join("waydroid.lock");
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    for _ in 0..2 {
        match fs::OpenOptions::new().write(true).create_new(true).open(&path) {
            Ok(mut file) => {
                let _ = writeln!(file, "{}", std::process::id());
                return Some(InstanceLock { path });
            }
            Err(_) => {
                let alive = fs::read_to_string(&path)
                    .ok()
                    .and_then(|value| value.trim().parse::<u32>().ok())
                    .map(|pid| Path::new(&format!("/proc/{}", pid)).exists())
                    .unwrap_or(false);
                if alive {
                    return None;
                }
                let _ = fs::remove_file(&path);
            }
        }
    }
    None
}

fn notify(summary: &str, body: &str, urgency: &str) {
    if load_config()
        .get("notifications")
        .map(String::as_str)
        .unwrap_or("true")
        != "true"
    {
        return;
    }
    if which("notify-send").is_none() {
        return;
    }
    let _ = Command::new("notify-send")
        .args(["-a", "Waydroid", "-i", "waydroid", "-u", urgency, summary, body])
        .status();
    if which("elvonos-sound").is_some() {
        let sound = if urgency == "critical" {
            "error"
        } else {
            "notification"
        };
        let _ = Command::new("elvonos-sound")
            .args(["play", sound])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn();
    }
}

// ---------------------------------------------------------------------------
// Process helpers

fn which(program: &str) -> Option<PathBuf> {
    let path = env::var_os("PATH")?;
    env::split_paths(&path)
        .map(|directory| directory.join(program))
        .find(|candidate| candidate.is_file())
}

fn output(program: &str, arguments: &[&str]) -> Option<Output> {
    Command::new(program).args(arguments).output().ok()
}

fn text(output: &Output) -> String {
    let mut value = String::from_utf8_lossy(&output.stdout).into_owned();
    value.push_str(&String::from_utf8_lossy(&output.stderr));
    value
}

fn container_active() -> bool {
    Command::new("systemctl")
        .args(["is-active", "--quiet", CONTAINER_UNIT])
        .status()
        .map(|status| status.success())
        .unwrap_or(false)
}

fn start_container() -> bool {
    if container_active() {
        return true;
    }
    // The graphics profile must be in place before LXC generates its config.
    let mode = resolved_graphics_mode();
    match apply_graphics_mode(&mode) {
        Ok(_) => log(&format!("graphics profile: {} ({})", mode, graphics_reason())),
        Err(error) => log(&format!("graphics profile '{}' not applied: {}", mode, error)),
    }
    log("starting waydroid-container.service");
    let status = Command::new("sudo")
        .args(["-n", "systemctl", "start", CONTAINER_UNIT])
        .status();
    matches!(status, Ok(value) if value.success())
}

fn stop_container() -> bool {
    let status = Command::new("sudo")
        .args(["-n", "systemctl", "stop", CONTAINER_UNIT])
        .status();
    matches!(status, Ok(value) if value.success())
}

fn session_running() -> bool {
    // Native detection first: the Waydroid session daemon keeps the command
    // line "waydroid session start" for its lifetime.  This avoids spawning
    // the Python CLI for every status poll.
    if let Ok(entries) = fs::read_dir("/proc") {
        for entry in entries.flatten() {
            let Some(name) = entry.file_name().to_str().map(str::to_string) else {
                continue;
            };
            if !name.chars().all(|character| character.is_ascii_digit()) {
                continue;
            }
            let Ok(raw) = fs::read(entry.path().join("cmdline")) else {
                continue;
            };
            if raw.is_empty() {
                continue;
            }
            let command = String::from_utf8_lossy(&raw).replace('\0', " ");
            if command.contains("elvonos-waydroid") && command.contains("session") {
                return true;
            }
            if command.contains("waydroid") && command.contains("session") && command.contains("start") {
                return true;
            }
        }
    }
    if which("waydroid").is_none() {
        return false;
    }
    let Some(result) = output("waydroid", &["status"]) else {
        return false;
    };
    let body = text(&result);
    body.lines().any(|line| {
        line.contains("Session:") && line.to_ascii_uppercase().contains("RUNNING")
    })
}

fn current_uid() -> u32 {
    output("id", &["-u"])
        .and_then(|result| text(&result).trim().parse().ok())
        .unwrap_or(1000)
}

fn current_gid() -> u32 {
    output("id", &["-g"])
        .and_then(|result| text(&result).trim().parse().ok())
        .unwrap_or(1000)
}

/// The live image ships /home/elvon/.local as root-owned.  Waydroid creates
/// ~/.local/share/waydroid as the session user, so repair ownership before the
/// first session start (idempotent and only touches the user's own directories).
fn repair_session_dirs() {
    let uid = current_uid();
    let gid = current_gid();
    for path in [home().join(".local"), home().join(".config")] {
        if let Ok(metadata) = fs::metadata(&path) {
            if metadata.uid() != uid {
                let _ = Command::new("sudo")
                    .args(["-n", "chown", "-R", &format!("{}:{}", uid, gid)])
                    .arg(&path)
                    .status();
            }
        } else {
            let _ = fs::create_dir_all(&path);
        }
    }
    let session = home().join(".local/share/waydroid");
    if let Ok(metadata) = fs::metadata(&session) {
        if metadata.uid() != uid {
            let _ = Command::new("sudo")
                .args(["-n", "chown", "-R", &format!("{}:{}", uid, gid)])
                .arg(&session)
                .status();
        }
    } else if let Some(parent) = session.parent() {
        let _ = fs::create_dir_all(parent);
    }
}

fn spawn_session(program: &str, arguments: &[&str]) -> bool {
    log(&format!("starting session: {} {:?}", program, arguments));
    if let Some(parent) = log_path().parent() {
        let _ = fs::create_dir_all(parent);
    }
    let file = fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(log_path());
    let mut command = Command::new("setsid");
    command.arg(program).args(arguments);
    if let Ok(handle) = file {
        let clone = handle.try_clone();
        command.stdout(Stdio::from(handle));
        if let Ok(clone) = clone {
            command.stderr(Stdio::from(clone));
        }
    }
    match command.spawn() {
        Ok(_) => true,
        Err(error) => {
            log(&format!("could not start session: {}", error));
            false
        }
    }
}

fn wait_for_session(timeout: Duration) -> bool {
    let started = Instant::now();
    while started.elapsed() < timeout {
        if session_running() {
            return true;
        }
        thread::sleep(Duration::from_millis(500));
    }
    false
}

fn start_session() -> bool {
    if session_running() {
        return true;
    }
    repair_session_dirs();
    if let Ok(executable) = env::current_exe() {
        if spawn_session(&executable.display().to_string(), &["session"])
            && wait_for_session(Duration::from_secs(15))
        {
            return true;
        }
    }
    if which("waydroid").is_none() {
        log("waydroid binary is missing");
        return false;
    }
    log("native session failed; falling back to upstream session");
    spawn_session("waydroid", &["session", "start"])
        && wait_for_session(Duration::from_secs(10))
}

fn lxc(arguments: &[&str]) -> Option<Output> {
    Command::new("sudo")
        .args([
            "-n",
            "lxc-attach",
            "-P",
            LXC_PATH,
            "-n",
            LXC_NAME,
            "--",
        ])
        .args(arguments)
        .output()
        .ok()
}

// Read-only probes must not block forever on a frozen container.
fn lxc_probe(arguments: &[&str]) -> Option<Output> {
    Command::new("timeout")
        .args([
            "15",
            "sudo",
            "-n",
            "lxc-attach",
            "-P",
            LXC_PATH,
            "-n",
            LXC_NAME,
            "--",
        ])
        .args(arguments)
        .output()
        .ok()
}

fn boot_completed() -> bool {
    if !container_active() {
        return false;
    }
    // A frozen container cannot answer binder/lxc probes; do not block on it.
    if container_state().as_deref() == Some("FROZEN") {
        return false;
    }
    lxc_probe(&["getprop", "sys.boot_completed"])
        .map(|result| text(&result).trim() == "1")
        .unwrap_or(false)
}

/// Android is usable when either the boot-complete property is set or the
/// package manager can resolve the framework package.  Some Waydroid/TCG boots
/// never set `sys.boot_completed` even though Android services (and `pm`) are
/// already available; the package-manager probe makes startup deterministic.
fn android_ready() -> bool {
    if container_state().as_deref() == Some("FROZEN") {
        return false;
    }
    if boot_completed() {
        return true;
    }
    let service = lxc_probe(&["service", "check", "package"])
        .map(|result| {
            let body = text(&result);
            body.contains("found") && !body.contains("not found")
        })
        .unwrap_or(false);
    if !service {
        return false;
    }
    lxc_probe(&["pm", "path", "android"])
        .map(|result| text(&result).contains("package:"))
        .unwrap_or(false)
}

fn wait_for_android(timeout: Duration, require_session: bool) -> bool {
    let started = Instant::now();
    let mut last_notice = 0u64;
    let mut iteration = 0u64;
    let mut session = if require_session { session_running() } else { true };
    while started.elapsed() < timeout {
        // While the user locked the desktop the container is frozen on purpose;
        // do not spin on probes or wake it up.
        if container_state().as_deref() == Some("FROZEN") {
            thread::sleep(Duration::from_secs(30));
            continue;
        }
        let booted = android_ready();
        if iteration % 3 == 0 {
            session = if require_session { session_running() } else { true };
        }
        if booted && (!require_session || session) {
            return true;
        }
        let elapsed = started.elapsed().as_secs();
        if elapsed >= last_notice + 30 {
            last_notice = elapsed;
            log(&format!(
                "waiting for Android (booted={}, session={}, {}s)",
                booted, session, elapsed
            ));
        }
        iteration += 1;
        // lxc-attach is expensive; polling every 5 s leaves more CPU for the
        // Android boot inside TCG/emulated environments.
        thread::sleep(Duration::from_secs(5));
    }
    false
}

fn ensure_ready(timeout: Duration, require_session: bool) -> bool {
    repair_session_dirs();
    let was_ready = android_ready() && (!require_session || session_running());
    let _lock = match try_lock() {
        Some(lock) => lock,
        None => {
            // Another instance is already starting Waydroid.  Wait for it
            // instead of spawning a second session and duplicate notification.
            return wait_for_android(timeout, require_session);
        }
    };
    if !was_ready {
        notify("Waydroid", &message("starting"), "normal");
    }
    if !start_container() {
        log("container failed to start");
        notify("Waydroid", &message("container-failed"), "critical");
        return false;
    }
    if require_session && !start_session() && which("waydroid").is_none() {
        log("session failed to start");
        notify("Waydroid", &message("session-failed"), "critical");
        return false;
    }
    if !wait_for_android(timeout, require_session) {
        log("timed out waiting for Android");
        notify("Waydroid", &message("boot-failed"), "critical");
        return false;
    }
    if !was_ready {
        log("Waydroid is ready");
        notify("Waydroid", &message("ready"), "low");
    }
    let _ = ensure_bridge();
    true
}

fn labels_path() -> PathBuf {
    state_dir().join("waydroid-labels.conf")
}

fn load_labels() -> HashMap<String, String> {
    let mut values = HashMap::new();
    if let Ok(text) = fs::read_to_string(labels_path()) {
        for line in text.lines() {
            if let Some((package, label)) = line.split_once('=') {
                values.insert(package.to_string(), label.to_string());
            }
        }
    }
    values
}

fn save_labels(values: &HashMap<String, String>) -> io::Result<()> {
    if let Some(parent) = labels_path().parent() {
        fs::create_dir_all(parent)?;
    }
    let mut keys: Vec<&String> = values.keys().collect();
    keys.sort();
    let mut text = String::new();
    for key in keys {
        text.push_str(key);
        text.push('=');
        text.push_str(values.get(key).map(String::as_str).unwrap_or(""));
        text.push('\n');
    }
    fs::write(labels_path(), text)
}

fn android_label(package: &str) -> Option<String> {
    let result = lxc_probe(&["dumpsys", "package", package])?;
    for line in text(&result).lines() {
        let line = line.trim();
        if let Some(value) = line.strip_prefix("application-label:") {
            let label = value.trim().trim_matches('\'').trim();
            if !label.is_empty() {
                return Some(label.to_string());
            }
        }
    }
    None
}

fn launcher_packages() -> HashSet<String> {
    let mut packages = HashSet::new();
    let Some(result) = lxc_probe(&[
        "cmd",
        "package",
        "query-activities",
        "-a",
        "android.intent.action.MAIN",
        "-c",
        "android.intent.category.LAUNCHER",
        "--brief",
    ]) else {
        return packages;
    };
    for line in text(&result).lines() {
        let token = line.trim();
        if token.is_empty() || token.starts_with("No activities") {
            continue;
        }
        let token = token.strip_prefix("package:").unwrap_or(token);
        let package = token.split('/').next().unwrap_or(token).trim();
        if package.contains('.') && !package.contains(' ') {
            packages.insert(package.to_string());
        }
    }
    packages
}

fn is_system_package(package: &str) -> bool {
    const SYSTEM: [&str; 14] = [
        "com.android.inputmethod",
        "com.android.settings",
        "com.android.systemui",
        "com.android.providers",
        "com.android.shell",
        "com.android.bluetooth",
        "com.android.phone",
        "com.android.server.telecom",
        "com.android.keychain",
        "com.android.certinstaller",
        "com.android.packageinstaller",
        "com.android.permissioncontroller",
        "com.android.documentsui",
        "com.android.launcher3",
    ];
    SYSTEM.iter().any(|prefix| package.starts_with(prefix))
}

fn native_application_list() -> Vec<(String, String)> {
    let packages = installed_packages();
    if packages.is_empty() {
        return Vec::new();
    }
    let launcher = launcher_packages();
    let mut labels = load_labels();
    let mut result = Vec::new();
    for package in packages {
        if is_system_package(&package) {
            continue;
        }
        if !launcher.is_empty() && !launcher.contains(&package) {
            continue;
        }
        let label = labels
            .get(&package)
            .cloned()
            .or_else(|| read_desktop_name(&desktop_path(&package)))
            .or_else(|| known_label(&package).map(str::to_string))
            .or_else(|| android_label(&package))
            .unwrap_or_else(|| package.clone());
        labels.insert(package.clone(), label.clone());
        result.push((package, label));
    }
    let _ = save_labels(&labels);
    result.sort_by(|left, right| left.1.to_lowercase().cmp(&right.1.to_lowercase()));
    result
}

fn app_count() -> usize {
    installed_packages().len()
}

fn waydroid_application_list() -> Vec<(String, String)> {
    // Native package manager query first; no Python/D-Bus needed.
    let native = native_application_list();
    if !native.is_empty() {
        return native;
    }
    if !session_running() {
        return Vec::new();
    }
    let Some(result) = Command::new("timeout")
        .args(["60", "waydroid", "app", "list"])
        .output()
        .ok()
    else {
        return Vec::new();
    };
    if !result.status.success() {
        return Vec::new();
    }
    let body = String::from_utf8_lossy(&result.stdout);
    let mut entries = Vec::new();
    let mut current: Option<String> = None;
    for raw in body.lines() {
        let line = raw.trim();
        if let Some(name) = line.strip_prefix("Name:") {
            current = Some(name.trim().to_string());
        } else if let Some(package) = line.strip_prefix("packageName:") {
            if let Some(name) = current.take() {
                let package = package.trim().to_string();
                if !package.is_empty() && !is_system_package(&package) {
                    entries.push((package, name));
                }
            }
        }
    }
    // The upstream listing also contains preinstalled LineageOS apps; keep
    // only third-party packages so the list matches the app count and the
    // Start-menu policy.
    let third_party = installed_packages();
    entries.retain(|(package, _)| third_party.contains(package));
    entries
}

fn installed_packages() -> HashSet<String> {
    let mut packages = HashSet::new();
    let Some(result) = lxc_probe(&["pm", "list", "packages", "-3"]) else {
        return packages;
    };
    for line in text(&result).lines() {
        if let Some(package) = line.trim().strip_prefix("package:") {
            packages.insert(package.trim().to_string());
        }
    }
    packages
}

fn storage_ready() -> bool {
    let mount = lxc_probe(&["service", "check", "mount"])
        .map(|result| {
            let body = text(&result);
            body.contains("found") && !body.contains("not found")
        })
        .unwrap_or(false);
    if !mount {
        return false;
    }
    lxc_probe(&["sm", "list-volumes"])
        .map(|result| {
            let body = text(&result);
            !body.trim().is_empty()
                && !body.contains("Exception")
                && !body.contains("Error")
        })
        .unwrap_or(false)
}

fn install_native(path: &Path) -> bool {
    // Wait until the package manager answers, then try immediately.  A fully
    // booted Android is ideal, but `sys.boot_completed` is not reliably set in
    // every emulated boot; the retry loop below handles a lagging
    // StorageManager without waiting for the property.
    if !android_ready() {
        return false;
    }
    let file_name = path
        .file_name()
        .and_then(|value| value.to_str())
        .unwrap_or("package.apk");
    let safe: String = file_name
        .chars()
        .map(|character| {
            if character.is_ascii_alphanumeric() || character == '.' || character == '-' || character == '_' {
                character
            } else {
                '_'
            }
        })
        .collect();
    let remote = format!("/data/local/tmp/elvonos-{}-{}.apk", std::process::id(), safe);

    let mut child = match Command::new("sudo")
        .args([
            "-n",
            "lxc-attach",
            "-P",
            LXC_PATH,
            "-n",
            LXC_NAME,
            "--",
            "sh",
            "-c",
            &format!("cat > {}", shell_quote(&remote)),
        ])
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
    {
        Ok(value) => value,
        Err(error) => {
            log(&format!("could not copy APK into container: {}", error));
            return false;
        }
    };

    if let Ok(mut file) = fs::File::open(path) {
        if let Some(mut stdin) = child.stdin.take() {
            let _ = io::copy(&mut file, &mut stdin);
        }
    }
    let _ = child.wait();

    // StorageManager can lag behind the package manager by several minutes on
    // slow (TCG) boots.  Keep the APK in /data/local/tmp and retry the install
    // until the storage service is usable or the 30-minute budget is spent.
    for attempt in 0..36 {
        // Try even when the readiness probes disagree; a StorageManager that
        // is a few seconds late simply returns an error and is retried.
        let _ready = boot_completed() || storage_ready();
        {
            let result = lxc(&["pm", "install", "-r", "-t", "--user", "0", &remote]);
            if let Some(output) = result {
                let body = text(&output);
                if body.contains("Success") {
                    let _ = lxc(&["rm", "-f", &remote]);
                    return true;
                }
                if attempt % 12 == 0 {
                    log(&format!(
                        "pm install attempt {} for {}: {}",
                        attempt + 1,
                        path.display(),
                        body.lines().next().unwrap_or("").trim()
                    ));
                }
            }
        }
        thread::sleep(Duration::from_secs(5));
    }
    let _ = lxc(&["rm", "-f", &remote]);
    false
}

fn install_apk(path: &Path) -> bool {
    if install_native(path) {
        return true;
    }
    if session_running() && which("waydroid").is_some() {
        // The upstream session may not see /usr/share; stage a user-readable
        // copy in the home directory first.
        let file_name = path
            .file_name()
            .and_then(|value| value.to_str())
            .unwrap_or("package.apk");
        let staging_dir = state_dir().join("apk");
        let _ = fs::create_dir_all(&staging_dir);
        let staged = staging_dir.join(file_name);
        if fs::copy(path, &staged).is_ok() {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(&staged, fs::Permissions::from_mode(0o644));
            log(&format!(
                "falling back to waydroid app install: {}",
                staged.display()
            ));
            return Command::new("timeout")
                .args(["300", "waydroid", "app", "install"])
                .arg(&staged)
                .status()
                .map(|status| status.success())
                .unwrap_or(false);
        }
    }
    false
}

fn shell_quote(value: &str) -> String {
    format!("'{}'", value.replace('\'', "'\\''"))
}

fn resolve_launcher_activity(package: &str) -> Option<String> {
    let result = lxc_probe(&[
        "cmd",
        "package",
        "resolve-activity",
        "--brief",
        "-a",
        "android.intent.action.MAIN",
        "-c",
        "android.intent.category.LAUNCHER",
        package,
    ])?;
    for line in text(&result).lines() {
        let line = line.trim();
        if line.starts_with(package) && line.contains('/') {
            return Some(line.to_string());
        }
    }
    None
}

fn android_task_visible(package: &str) -> bool {
    // Use a short timeout: dumpsys can hang while Android is still booting.
    let output = Command::new("timeout")
        .args([
            "5",
            "sudo",
            "-n",
            "lxc-attach",
            "-P",
            LXC_PATH,
            "-n",
            LXC_NAME,
            "--",
            "dumpsys",
            "activity",
            "activities",
        ])
        .output();
    output
        .map(|result| text(&result).contains(package))
        .unwrap_or(false)
}

fn launch_native(package: &str) -> bool {
    if !android_ready() {
        return false;
    }
    let _ = lxc(&["setprop", "waydroid.active_apps", package]);
    let Some(component) = resolve_launcher_activity(package) else {
        return false;
    };
    let _ = lxc(&[
        "settings",
        "put",
        "--user",
        "0",
        "global",
        "policy_control",
        "immersive.full=*",
    ]);
    let result = lxc(&["am", "start", "--user", "0", "-n", &component]);
    let Some(output) = result else {
        return false;
    };
    let body = text(&output);
    if body.contains("Error") && !body.contains("Starting:") {
        log(&format!(
            "native launch failed for {}: {}",
            package,
            body.lines().next().unwrap_or("").trim()
        ));
        return false;
    }
    thread::sleep(Duration::from_secs(2));
    // Only claim native success when Android actually reports the task.  If
    // the task dump is unavailable (early boot) or the task did not appear,
    // the caller falls back to the upstream platform-service launcher.
    if android_task_visible(package) {
        true
    } else {
        log(&format!(
            "native launch did not create a task for {}; using platform service",
            package
        ));
        false
    }
}

fn launch_package(package: &str) -> bool {
    // Native path first: set the Android active app and start its launcher
    // activity directly through the package manager.  The Waydroid platform
    // service turns the Android task into a Wayland window in multi-window
    // mode.
    if launch_native(package) {
        return true;
    }
    if which("waydroid").is_some() && session_running() {
        if let Some(status) = Command::new("waydroid")
            .args(["app", "launch", package])
            .status()
            .ok()
        {
            if status.success() {
                return true;
            }
        }
    }
    if android_ready() {
        let result = lxc(&[
            "monkey",
            "-p",
            package,
            "-c",
            "android.intent.category.LAUNCHER",
            "1",
        ]);
        return result
            .map(|output| !text(&output).contains("No activities found"))
            .unwrap_or(false);
    }
    false
}

// ---------------------------------------------------------------------------
// APK metadata (binary AndroidManifest.xml)

fn read_u16(data: &[u8], offset: usize) -> Option<u16> {
    Some(u16::from_le_bytes([
        *data.get(offset)?,
        *data.get(offset + 1)?,
    ]))
}

fn read_u32(data: &[u8], offset: usize) -> Option<u32> {
    Some(u32::from_le_bytes([
        *data.get(offset)?,
        *data.get(offset + 1)?,
        *data.get(offset + 2)?,
        *data.get(offset + 3)?,
    ]))
}

fn read_length8(data: &[u8], offset: usize) -> Option<(usize, usize)> {
    let first = *data.get(offset)? as usize;
    if first & 0x80 != 0 {
        let second = *data.get(offset + 1)? as usize;
        Some((((first & 0x7f) << 8) | second, offset + 2))
    } else {
        Some((first, offset + 1))
    }
}

fn read_string_pool(data: &[u8], start: usize) -> Vec<String> {
    let mut result = Vec::new();
    if read_u16(data, start) != Some(0x0001) {
        return result;
    }
    let header_size = match read_u16(data, start + 2) {
        Some(value) => value as usize,
        None => return result,
    };
    let count = match read_u32(data, start + 8) {
        Some(value) => value as usize,
        None => return result,
    };
    let flags = match read_u32(data, start + 16) {
        Some(value) => value,
        None => return result,
    };
    let strings_start = match read_u32(data, start + 20) {
        Some(value) => value as usize,
        None => return result,
    };
    let base = start.saturating_add(strings_start);
    let utf8 = flags & 0x0100 != 0;
    for index in 0..count {
        let Some(offset) = read_u32(data, start + header_size + index * 4) else {
            break;
        };
        let position = base.saturating_add(offset as usize);
        if utf8 {
            let Some((_characters, position)) = read_length8(data, position) else {
                continue;
            };
            let Some((size, position)) = read_length8(data, position) else {
                continue;
            };
            if position + size <= data.len() {
                result.push(
                    String::from_utf8_lossy(&data[position..position + size]).into_owned(),
                );
            } else {
                result.push(String::new());
            }
        } else {
            let Some(mut length) = read_u16(data, position) else {
                continue;
            };
            let mut position = position + 2;
            if length & 0x8000 != 0 {
                let Some(low) = read_u16(data, position) else {
                    continue;
                };
                length = ((((length as u32) & 0x7fff) << 16) | low as u32) as u16;
                position += 2;
            }
            let bytes = length as usize * 2;
            if position + bytes <= data.len() {
                let units: Vec<u16> = data[position..position + bytes]
                    .chunks_exact(2)
                    .map(|pair| u16::from_le_bytes([pair[0], pair[1]]))
                    .collect();
                result.push(String::from_utf16_lossy(&units));
            } else {
                result.push(String::new());
            }
        }
    }
    result
}

fn manifest_package(data: &[u8]) -> Option<String> {
    if read_u16(data, 0) != Some(0x0003) {
        return None;
    }
    let total = (read_u32(data, 4)? as usize).min(data.len());
    let mut strings: Vec<String> = Vec::new();
    let mut position = 8usize;
    while position + 8 <= total {
        let chunk_type = read_u16(data, position)?;
        let header_size = read_u16(data, position + 2)? as usize;
        let chunk_size = read_u32(data, position + 4)? as usize;
        if chunk_size < 8 {
            break;
        }
        if chunk_type == 0x0001 {
            strings = read_string_pool(data, position);
        } else if chunk_type == 0x0102 {
            let name_index = read_u32(data, position + 20)? as usize;
            let attribute_start = read_u16(data, position + 28)? as usize;
            let attribute_size = read_u16(data, position + 30)? as usize;
            let attribute_count = read_u16(data, position + 32)? as usize;
            if strings.get(name_index).map(String::as_str) == Some("manifest") {
                let attributes = position + header_size + attribute_start;
                for index in 0..attribute_count {
                    let base = attributes + index * attribute_size;
                    if base + 20 > total {
                        break;
                    }
                    let attribute_name = read_u32(data, base + 4)? as usize;
                    let data_type = *data.get(base + 15)?;
                    let value = read_u32(data, base + 16)? as usize;
                    if data_type == 0x03
                        && strings.get(attribute_name).map(String::as_str) == Some("package")
                    {
                        if let Some(package) = strings.get(value) {
                            return Some(package.clone());
                        }
                    }
                }
            }
        }
        position += chunk_size;
    }
    None
}

fn apk_package(path: &Path) -> Option<String> {
    let result = Command::new("unzip")
        .args(["-p"])
        .arg(path)
        .arg("AndroidManifest.xml")
        .output()
        .ok()?;
    if !result.status.success() || result.stdout.is_empty() {
        return None;
    }
    manifest_package(&result.stdout)
}

fn pretty_label(path: &Path) -> String {
    let stem = path
        .file_stem()
        .and_then(|value| value.to_str())
        .unwrap_or("Android App");
    let mut label = stem.to_string();
    if let Some(index) = label.find(|character: char| character == '-' || character == '_') {
        let candidate = &label[index + 1..];
        if candidate
            .chars()
            .next()
            .map(|character| character.is_ascii_digit())
            .unwrap_or(false)
        {
            label.truncate(index);
        }
    }
    label = label.replace(['_', '-'], " ");
    let mut spaced = String::new();
    let mut previous_lower = false;
    for character in label.chars() {
        if character.is_uppercase() && previous_lower {
            spaced.push(' ');
        }
        previous_lower = character.is_lowercase() || character.is_ascii_digit();
        spaced.push(character);
    }
    let trimmed = spaced.trim();
    if trimmed.is_empty() {
        "Android App".into()
    } else {
        trimmed.to_string()
    }
}

fn known_package(file_name: &str) -> Option<&'static str> {
    let lower = file_name.to_ascii_lowercase();
    if lower.starts_with("aurorastore") || lower.contains("aurora") {
        Some("com.aurora.store")
    } else if lower.starts_with("com.google.android.gms") {
        Some("com.google.android.gms")
    } else if lower.starts_with("com.android.vending") {
        Some("com.android.vending")
    } else {
        None
    }
}

fn known_label(package: &str) -> Option<&'static str> {
    match package {
        "com.aurora.store" => Some("Aurora Store"),
        "com.google.android.gms" => Some("microG Services"),
        "com.android.vending" => Some("microG Companion"),
        _ => None,
    }
}

fn apk_identity(path: &Path) -> Option<(String, String)> {
    let package = apk_package(path).or_else(|| {
        path.file_name()
            .and_then(|value| value.to_str())
            .and_then(known_package)
            .map(str::to_string)
    })?;
    let label = known_label(&package)
        .map(str::to_string)
        .unwrap_or_else(|| pretty_label(path));
    Some((package, label))
}

// ---------------------------------------------------------------------------
// Desktop integration

fn escape_desktop(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace(['\n', '\r'], " ")
}

fn safe_name(package: &str) -> String {
    package
        .chars()
        .map(|character| {
            if character.is_ascii_alphanumeric() || character == '.' || character == '-' || character == '_' {
                character
            } else {
                '_'
            }
        })
        .collect()
}

fn desktop_path(package: &str) -> PathBuf {
    applications_dir().join(format!("waydroid-{}.desktop", safe_name(package)))
}

fn icon_cache_dir() -> PathBuf {
    data_home().join("icons/elvonos/android")
}

fn package_apk_path(package: &str) -> Option<String> {
    let result = lxc_probe(&["pm", "path", package])?;
    for line in text(&result).lines() {
        if let Some(path) = line.trim().strip_prefix("package:") {
            if path.ends_with(".apk") {
                return Some(path.to_string());
            }
        }
    }
    None
}

fn android_icon_resource(package: &str) -> Option<String> {
    let result = lxc_probe(&["dumpsys", "package", package])?;
    let mut best_density = 0u32;
    let mut best = None;
    for line in text(&result).lines() {
        let line = line.trim();
        let Some(rest) = line.strip_prefix("application-icon-") else {
            continue;
        };
        let Some((density, value)) = rest.split_once(':') else {
            continue;
        };
        let Ok(density) = density.parse::<u32>() else {
            continue;
        };
        let resource = value.trim().trim_matches('\'').trim();
        if (resource.ends_with(".png") || resource.ends_with(".webp"))
            && density >= best_density
        {
            best_density = density;
            best = Some(resource.to_string());
        }
    }
    best
}

fn lxc_copy_to_file(arguments: &[&str], destination: &Path) -> bool {
    let Ok(file) = fs::File::create(destination) else {
        return false;
    };
    Command::new("sudo")
        .args([
            "-n",
            "lxc-attach",
            "-P",
            LXC_PATH,
            "-n",
            LXC_NAME,
            "--",
        ])
        .args(arguments)
        .stdout(Stdio::from(file))
        .stderr(Stdio::null())
        .status()
        .map(|status| status.success())
        .unwrap_or(false)
}

fn png_size(path: &Path) -> Option<(u32, u32)> {
    let data = fs::read(path).ok()?;
    if data.len() < 24 || &data[..8] != b"\x89PNG\r\n\x1a\n" {
        return None;
    }
    let width = u32::from_be_bytes([data[16], data[17], data[18], data[19]]);
    let height = u32::from_be_bytes([data[20], data[21], data[22], data[23]]);
    Some((width, height))
}

fn apk_icon_entry(apk: &Path) -> Option<String> {
    // Resource names in modern APKs are often obfuscated (Aurora uses
    // `res/CH.png`), so pick the largest square PNG instead of matching names.
    let output = Command::new("unzip").args(["-l"]).arg(apk).output().ok()?;
    if !output.status.success() {
        return None;
    }
    let body = String::from_utf8_lossy(&output.stdout);
    let mut candidates: Vec<(u64, String)> = Vec::new();
    for line in body.lines() {
        let fields: Vec<&str> = line.split_whitespace().collect();
        if fields.len() < 4 {
            continue;
        }
        let Ok(size) = fields[0].parse::<u64>() else {
            continue;
        };
        let name = fields[fields.len() - 1];
        let lower = name.to_lowercase();
        if !lower.starts_with("res/") || !lower.ends_with(".png") || lower.ends_with(".9.png") {
            continue;
        }
        candidates.push((size, name.to_string()));
    }
    candidates.sort_by(|left, right| right.0.cmp(&left.0));
    let probe = std::env::temp_dir().join(format!("elvonos-icon-{}.png", std::process::id()));
    let mut fallback = None;
    for (_, entry) in candidates.iter().take(24) {
        let extracted = Command::new("unzip")
            .args(["-p"])
            .arg(apk)
            .arg(entry)
            .stdout(Stdio::from(fs::File::create(&probe).ok()?))
            .stderr(Stdio::null())
            .status();
        if !extracted.map(|status| status.success()).unwrap_or(false) {
            continue;
        }
        if let Some((width, height)) = png_size(&probe) {
            if width == height && width >= 96 {
                let _ = fs::remove_file(&probe);
                return Some(entry.clone());
            }
        }
        if fallback.is_none() {
            fallback = Some(entry.clone());
        }
    }
    let _ = fs::remove_file(&probe);
    fallback
}

fn cached_package_icon(package: &str) -> Option<PathBuf> {
    let directory = icon_cache_dir();
    let safe = safe_name(package);
    for extension in ["png", "webp"] {
        let candidate = directory.join(format!("{}.{}", safe, extension));
        if candidate.is_file() {
            return Some(candidate);
        }
    }
    None
}

fn ensure_package_icon(package: &str) -> Option<PathBuf> {
    if let Some(cached) = cached_package_icon(package) {
        return Some(cached);
    }
    let directory = icon_cache_dir();
    let safe = safe_name(package);
    let apk_path = package_apk_path(package)?;
    let temporary = state_dir().join(format!("{}.apk", safe));
    if let Some(parent) = temporary.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let local_apk: Option<PathBuf> = {
        // Waydroid bind-mounts the user data directory (default
        // ~/.local/share/waydroid/data) into the container as /data, so the
        // APK can be read directly on the host without lxc-attach.
        let mut direct = None;
        if let Some(relative) = apk_path.strip_prefix("/data/") {
            for base in [
                data_home().join("waydroid/data"),
                PathBuf::from("/var/lib/waydroid/data"),
            ] {
                let candidate = base.join(relative);
                if candidate.is_file() {
                    direct = Some(candidate);
                    break;
                }
            }
        }
        if direct.is_none() && lxc_copy_to_file(&["cat", &apk_path], &temporary) {
            let readable = fs::metadata(&temporary).map(|value| value.len() > 0).unwrap_or(false);
            if !readable {
                let _ = fs::remove_file(&temporary);
                return None;
            }
        }
        direct.or_else(|| temporary.is_file().then(|| temporary.clone()))
    };
    let Some(apk) = local_apk else {
        let _ = fs::remove_file(&temporary);
        return None;
    };
    let Some(resource) = android_icon_resource(package).or_else(|| apk_icon_entry(&apk)) else {
        let _ = fs::remove_file(&temporary);
        return None;
    };
    let extension = if resource.ends_with(".webp") { "webp" } else { "png" };
    let destination = directory.join(format!("{}.{}", safe, extension));
    let _ = fs::create_dir_all(&directory);
    let result = Command::new("unzip")
        .args(["-p"])
        .arg(&apk)
        .arg(&resource)
        .stdout(Stdio::from(fs::File::create(&destination).ok()?))
        .stderr(Stdio::null())
        .status();
    let _ = fs::remove_file(&temporary);
    if result.map(|status| status.success()).unwrap_or(false)
        && fs::metadata(&destination).map(|value| value.len() > 0).unwrap_or(false)
    {
        Some(destination)
    } else {
        let _ = fs::remove_file(&destination);
        None
    }
}

fn write_desktop_entry(
    package: &str,
    label: &str,
    overwrite: bool,
    icon_override: Option<&Path>,
) -> io::Result<PathBuf> {
    let directory = applications_dir();
    fs::create_dir_all(&directory)?;
    let path = directory.join(format!("waydroid-{}.desktop", safe_name(package)));
    if path.exists() && !overwrite {
        return Ok(path);
    }
    let icon = if let Some(path) = icon_override {
        path.display().to_string()
    } else if package == "com.aurora.store" {
        AURORA_ICON.to_string()
    } else {
        "waydroid".to_string()
    };
    let generic = localized("generic");
    let comment = localized("comment");
    let mut text = String::new();
    text.push_str("[Desktop Entry]\n");
    text.push_str("Type=Application\n");
    text.push_str(&format!("Name={}\n", escape_desktop(label)));
    text.push_str(&format!("GenericName={}\n", escape_desktop(&generic)));
    text.push_str(&format!("Comment={}\n", escape_desktop(&comment)));
    for (code, locale) in LOCALES {
        if code == "en" || locale.is_empty() {
            continue;
        }
        let generic_value = GENERIC_NAMES
            .iter()
            .find(|(key, _)| *key == code)
            .map(|(_, value)| *value)
            .unwrap_or("");
        let comment_value = COMMENTS
            .iter()
            .find(|(key, _)| *key == code)
            .map(|(_, value)| *value)
            .unwrap_or("");
        text.push_str(&format!(
            "GenericName[{}]={}\n",
            locale,
            escape_desktop(generic_value)
        ));
        text.push_str(&format!(
            "Comment[{}]={}\n",
            locale,
            escape_desktop(comment_value)
        ));
    }
    text.push_str(&format!("Exec=elvonos-waydroid {}\n", package));
    text.push_str(&format!("Icon={}\n", icon));
    text.push_str("Terminal=false\n");
    text.push_str("StartupNotify=false\n");
    text.push_str("Categories=X-WayDroid-App;Utility;\n");
    text.push_str(ANDROID_MARKER);
    text.push('\n');
    fs::write(&path, text)?;
    Ok(path)
}

fn read_desktop_name(path: &Path) -> Option<String> {
    let text = fs::read_to_string(path).ok()?;
    text.lines()
        .find_map(|line| line.strip_prefix("Name=").map(|value| value.trim().to_string()))
}

fn sync_entries() -> i32 {
    let listed = waydroid_application_list();
    let mut entries: BTreeMap<String, String> = BTreeMap::new();
    if listed.is_empty() {
        if !android_ready() {
            log("sync skipped: Android is not running");
            return 0;
        }
        let packages = installed_packages();
        if packages.is_empty() {
            log("sync skipped: no packages returned");
            return 0;
        }
        for package in packages {
            let label = read_desktop_name(&desktop_path(&package))
                .or_else(|| known_label(&package).map(str::to_string))
                .unwrap_or_else(|| package.clone());
            entries.insert(package, label);
        }
    } else {
        for (package, label) in listed {
            entries.insert(package, label);
        }
    }

    let mut written = HashSet::new();
    let mut count = 0;
    for (package, label) in &entries {
        let icon = ensure_package_icon(package);
        if write_desktop_entry(package, label, true, icon.as_deref()).is_ok() {
            written.insert(format!("waydroid-{}.desktop", safe_name(package)));
            count += 1;
        }
    }

    if let Ok(directory) = fs::read_dir(applications_dir()) {
        for entry in directory.flatten() {
            let name = entry.file_name();
            let Some(name) = name.to_str() else {
                continue;
            };
            if !name.starts_with("waydroid-") || !name.ends_with(".desktop") {
                continue;
            }
            if written.contains(name) {
                continue;
            }
            let path = entry.path();
            if let Ok(text) = fs::read_to_string(&path) {
                if text.contains(ANDROID_MARKER) {
                    let _ = fs::remove_file(path);
                }
            }
        }
    }

    if which("update-desktop-database").is_some() {
        let _ = Command::new("update-desktop-database")
            .arg(applications_dir())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();
    }
    write_state(Some(count as u64), None);
    log(&format!("synchronised {} Android app(s)", count));
    println!("Synchronised {} Android app(s).", count);
    0
}

fn write_state(apps: Option<u64>, error: Option<&str>) {
    let session = session_running();
    let frozen = container_state().as_deref() == Some("FROZEN");
    let booted = if frozen { false } else { android_ready() };
    let container = container_active();
    let count = apps.unwrap_or(0);
    let last_sync = if apps.is_some() {
        format!("\"{}\"", timestamp())
    } else {
        "null".into()
    };
    let error_value = match error {
        Some(value) => format!("\"{}\"", json_escape(value)),
        None => "null".into(),
    };
    let body = format!(
        "{{\"container\":{},\"session\":{},\"booted\":{},\"apps\":{},\"lastSync\":{},\"error\":{},\"version\":\"{}\"}}\n",
        container, session, booted, count, last_sync, error_value, VERSION
    );
    if let Some(parent) = state_path().parent() {
        let _ = fs::create_dir_all(parent);
    }
    let _ = fs::write(state_path(), body);
}

fn json_escape(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
        .replace('\r', "\\r")
        .replace('\t', "\\t")
}

// ---------------------------------------------------------------------------
// Commands

fn cmd_start() -> i32 {
    let _ = fs::remove_file(pause_path());
    if ensure_ready(Duration::from_secs(1800), true) {
        println!("Waydroid is ready.");
        0
    } else {
        eprintln!("Waydroid could not be started.");
        1
    }
}

fn cmd_session() -> i32 {
    repair_session_dirs();
    if !start_container() {
        log("session: container failed to start");
        return 1;
    }
    let connection = match Connection::new_session() {
        Ok(value) => value,
        Err(error) => {
            log(&format!("session: cannot connect to session bus: {}", error));
            return 1;
        }
    };
    if let Err(error) = connection.request_name("id.waydro.Session", false, true, false) {
        log(&format!("session: cannot own id.waydro.Session: {}", error));
        return 1;
    }
    if let Some(parent) = session_pid_path().parent() {
        let _ = fs::create_dir_all(parent);
    }
    let _ = fs::write(session_pid_path(), format!("{}\n", std::process::id()));
    if let Err(error) = native_session_start() {
        let _ = fs::remove_file(session_pid_path());
        log(&format!("session: container Start failed: {}", error));
        return 1;
    }
    log(&format!("native session started (pid {})", std::process::id()));
    let _ = ensure_bridge();
    loop {
        let _ = connection.process(Duration::from_millis(500));
    }
}

fn cmd_stop() -> i32 {
    if let Some(parent) = pause_path().parent() {
        let _ = fs::create_dir_all(parent);
    }
    let _ = fs::write(pause_path(), "paused\n");
    stop_bridge();
    let mut stopped_native = false;
    if let Ok(text) = fs::read_to_string(session_pid_path()) {
        if let Ok(pid) = text.trim().parse::<u32>() {
            let _ = Command::new("kill").arg(pid.to_string()).status();
            stopped_native = true;
        }
        let _ = fs::remove_file(session_pid_path());
    }
    if !stopped_native && which("waydroid").is_some() {
        let _ = Command::new("waydroid")
            .args(["session", "stop"])
            .status();
    }
    let _ = native_container_stop();
    let stopped = stop_container();
    write_state(Some(0), None);
    if stopped || !container_active() {
        println!("Waydroid stopped.");
        0
    } else {
        eprintln!("Waydroid could not be stopped.");
        1
    }
}

fn cmd_status(json: bool) -> i32 {
    let container = container_active();
    let session = session_running();
    let frozen = container_state()
        .map(|state| state == "FROZEN")
        .unwrap_or(false);
    let booted = if frozen { false } else { android_ready() };
    let apps = if booted { app_count() } else { 0 };
    let autostart = load_config()
        .get("autostart")
        .cloned()
        .unwrap_or_else(|| "false".into());
    if json {
        println!(
            "{{\"container\":{},\"session\":{},\"booted\":{},\"frozen\":{},\"apps\":{},\"autostart\":{},\"daemon\":{},\"bridge\":{},\"multiwindow\":{},\"state\":\"{}\",\"log\":\"{}\"}}",
            container,
            session,
            booted,
            frozen,
            apps,
            autostart == "true",
            daemon_running(),
            bridge_running(),
            load_config()
                .get("multiwindow")
                .map(|value| value == "true")
                .unwrap_or(true),
            state_path().display(),
            log_path().display()
        );
    } else {
        println!("Waydroid status");
        println!("  Container:   {}", if container { "active" } else { "stopped" });
        println!("  Session:     {}", if session { "running" } else { "stopped" });
        println!(
            "  Android:     {}",
            if frozen {
                "frozen"
            } else if booted {
                "booted"
            } else {
                "not booted"
            }
        );
        println!("  Apps:        {}", apps);
        println!("  Autostart:   {}", if autostart == "true" { "on" } else { "off" });
        println!("  Supervisor:  {}", if daemon_running() { "running" } else { "stopped" });
        println!("  State file:  {}", state_path().display());
        println!("  Log:         {}", log_path().display());
    }
    write_state(Some(apps as u64), None);
    0
}

fn cmd_launch(package: Option<&str>) -> i32 {
    if !ensure_ready(Duration::from_secs(1800), true) {
        eprintln!("Waydroid is not ready.");
        return 1;
    }
    if let Some(package) = package {
        // Launching an existing Start-menu entry must stay fast: do not block
        // on the bundled-app installer (which can retry for minutes on a slow
        // Android boot).  The no-package case below bootstraps the apps.
        if package.is_empty() {
            return 0;
        }
        if launch_package(package) {
            0
        } else {
            eprintln!("Could not launch {}.", package);
            1
        }
    } else {
        let _ = install_bundled();
        let _ = sync_entries();
        0
    }
}

fn install_bundled() -> Result<usize, String> {
    let directory = Path::new(APPS_DIR);
    let Ok(entries) = fs::read_dir(directory) else {
        return Ok(0);
    };
    let installed = installed_packages();
    let mut count = 0;
    let mut files: Vec<PathBuf> = entries
        .flatten()
        .map(|entry| entry.path())
        .filter(|path| path.extension().and_then(|value| value.to_str()) == Some("apk"))
        .collect();
    files.sort();
    for path in files {
        let Some((package, _)) = apk_identity(&path) else {
            log(&format!("skipping unknown APK: {}", path.display()));
            continue;
        };
        if installed.contains(&package) {
            continue;
        }
        log(&format!("installing bundled {}", package));
        let mut installed_ok = install_apk(&path);
        if !installed_ok {
            // The package manager can answer `pm path` slightly before it is
            // ready for installs; retry once after a short pause.
            thread::sleep(Duration::from_secs(5));
            installed_ok = install_apk(&path);
        }
        if installed_ok {
            count += 1;
        } else {
            log(&format!("bundled installation failed: {}", package));
        }
    }
    Ok(count)
}

fn cmd_apps() -> i32 {
    if !ensure_ready(Duration::from_secs(1800), true) {
        eprintln!("Waydroid is not ready.");
        return 1;
    }
    match install_bundled() {
        Ok(count) => {
            if count > 0 {
                notify(
                    "Waydroid",
                    &format!("{} bundled Android app(s) installed.", count),
                    "low",
                );
            }
            sync_entries()
        }
        Err(error) => {
            eprintln!("{}", error);
            write_state(None, Some(&error));
            1
        }
    }
}

fn cmd_list(json: bool) -> i32 {
    if !android_ready() {
        if json {
            println!("[]");
        }
        return 0;
    }
    let entries = waydroid_application_list();
    if json {
        let body: Vec<String> = entries
            .iter()
            .map(|(package, label)| {
                let icon = cached_package_icon(package)
                    .map(|path| path.display().to_string())
                    .unwrap_or_default();
                format!(
                    "{{\"package\":\"{}\",\"label\":\"{}\",\"icon\":\"{}\"}}",
                    json_escape(package),
                    json_escape(label),
                    json_escape(&icon)
                )
            })
            .collect();
        println!("[{}]", body.join(","));
    } else {
        for (package, label) in entries {
            println!("{}\t{}", package, label);
        }
    }
    0
}

fn cmd_remove(package: Option<&str>) -> i32 {
    let Some(package) = package else {
        eprintln!("usage: elvonos-waydroid remove PACKAGE");
        return 2;
    };
    if !ensure_ready(Duration::from_secs(180), false) {
        eprintln!("Waydroid is not ready.");
        return 1;
    }
    let result = lxc(&["pm", "uninstall", package]);
    let success = result
        .map(|output| text(&output).contains("Success"))
        .unwrap_or(false);
    if success {
        let _ = fs::remove_file(desktop_path(package));
        let _ = sync_entries();
        notify(
            "Waydroid",
            &format!("{} was uninstalled.", package),
            "low",
        );
        println!("{} was uninstalled.", package);
        0
    } else {
        eprintln!("Could not uninstall {}.", package);
        1
    }
}

fn cmd_sync() -> i32 {
    sync_entries()
}

fn cmd_install(files: &[String]) -> i32 {
    let mut selected: Vec<PathBuf> = files
        .iter()
        .filter(|value| !value.starts_with('-'))
        .map(PathBuf::from)
        .collect();

    if selected.is_empty() {
        let Some(zenity) = which("zenity") else {
            eprintln!("No APK given and zenity is not installed.");
            return 2;
        };
        let selection = Command::new(zenity)
            .args([
                "--file-selection",
                "--multiple",
                "--separator=\n",
                "--title=APK Installer",
                "--file-filter=Android APK (*.apk) | *.apk",
            ])
            .output();
        let Ok(selection) = selection else {
            return 2;
        };
        if !selection.status.success() {
            return 0;
        }
        for line in String::from_utf8_lossy(&selection.stdout).lines() {
            let line = line.trim();
            if !line.is_empty() {
                selected.push(PathBuf::from(line));
            }
        }
    }

    selected.retain(|path| path.is_file());
    if selected.is_empty() {
        return 0;
    }

    if !ensure_ready(Duration::from_secs(600), true) {
        notify("Waydroid", &message("not-ready"), "critical");
        return 1;
    }

    let mut installed = 0;
    let mut failed: Vec<String> = Vec::new();
    for path in &selected {
        log(&format!("installing {}", path.display()));
        if install_apk(path) {
            installed += 1;
            if let Some((package, label)) = apk_identity(path) {
                let _ = write_desktop_entry(&package, &label, true, None);
            }
        } else {
            failed.push(
                path.file_name()
                    .and_then(|value| value.to_str())
                    .unwrap_or("APK")
                    .to_string(),
            );
        }
    }
    let _ = sync_entries();

    if failed.is_empty() {
        notify(
            "Waydroid",
            &format!("{} Android app(s) installed.", installed),
            "low",
        );
        println!("{} Android app(s) installed.", installed);
        0
    } else {
        let message = format!(
            "{} installed, {} failed: {}",
            installed,
            failed.len(),
            failed.join(", ")
        );
        notify("Waydroid", &message, "critical");
        eprintln!("{}", message);
        1
    }
}

fn cmd_apk_entry(arguments: &[String]) -> i32 {
    let Some(path) = arguments.first() else {
        eprintln!("usage: elvonos-waydroid apk-entry APK [LABEL]");
        return 2;
    };
    let path = Path::new(path);
    let Some((package, default_label)) = apk_identity(path) else {
        eprintln!("Could not read the package name from {}.", path.display());
        return 1;
    };
    let label = arguments
        .get(1)
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or(default_label);
    match write_desktop_entry(&package, &label, false, None) {
        Ok(_) => 0,
        Err(error) => {
            eprintln!("Could not write the desktop entry: {}", error);
            1
        }
    }
}

fn cmd_doctor() -> i32 {
    let mut warnings = 0;
    let mut failures = 0;
    println!("ElvonOS Waydroid doctor");
    check("waydroid binary", which("waydroid").is_some(), false, &mut failures, &mut warnings);
    check("unzip available", which("unzip").is_some(), false, &mut failures, &mut warnings);
    check("notify-send available", which("notify-send").is_some(), true, &mut failures, &mut warnings);
    check(
        "Waydroid images",
        Path::new("/usr/share/waydroid/images/system.img").exists()
            || Path::new("/usr/share/waydroid-extra/images/system.img").exists()
            || Path::new("/var/lib/waydroid/images/system.img").exists(),
        false,
        &mut failures,
        &mut warnings,
    );
    check(
        "LXC container directory",
        Path::new(LXC_PATH).join(LXC_NAME).exists(),
        false,
        &mut failures,
        &mut warnings,
    );
    check(
        "Binder device",
        Path::new("/dev/binderfs").exists()
            || Path::new("/dev/binder").exists()
            || Path::new("/dev/anbox-binder").exists(),
        true,
        &mut failures,
        &mut warnings,
    );
    let sudo_ok = Command::new("sudo")
        .args(["-n", "true"])
        .status()
        .map(|status| status.success())
        .unwrap_or(false);
    check("passwordless sudo", sudo_ok, false, &mut failures, &mut warnings);
    check("container active", container_active(), true, &mut failures, &mut warnings);
    check("session running", session_running(), true, &mut failures, &mut warnings);
    check("Android booted", boot_completed(), true, &mut failures, &mut warnings);
    check(
        "bundled APK directory",
        Path::new(APPS_DIR).is_dir(),
        false,
        &mut failures,
        &mut warnings,
    );
    if let Ok(entries) = fs::read_dir(APPS_DIR) {
        let count = entries
            .flatten()
            .filter(|entry| entry.path().extension().and_then(|value| value.to_str()) == Some("apk"))
            .count();
        println!("  Bundled APKs:          {}", count);
    }
    println!(
        "\n{} failure(s), {} warning(s).",
        failures, warnings
    );
    if failures > 0 {
        1
    } else {
        0
    }
}

fn check(
    label: &str,
    ok: bool,
    warning_only: bool,
    failures: &mut u32,
    warnings: &mut u32,
) {
    let state = if ok {
        "OK"
    } else if warning_only {
        *warnings += 1;
        "WARN"
    } else {
        *failures += 1;
        "FAIL"
    };
    println!("  {:<24} {}", format!("{}:", label), state);
}

fn cmd_recover() -> i32 {
    log("recovery requested");
    if !start_container() {
        eprintln!("The Waydroid container could not be started.");
        return 1;
    }
    if !session_running() {
        start_session();
    }
    if !wait_for_android(Duration::from_secs(180), false) {
        eprintln!("Android did not respond; restarting the container.");
        let _ = stop_container();
        thread::sleep(Duration::from_secs(2));
        if !start_container() {
            return 1;
        }
        start_session();
        if !wait_for_android(Duration::from_secs(300), false) {
            eprintln!("Waydroid is still not responding.");
            return 1;
        }
    }
    let _ = sync_entries();
    println!("Waydroid recovered.");
    0
}

fn daemon_cycle() -> bool {
    if fs::metadata(pause_path()).is_ok() {
        return false;
    }
    if !android_ready() {
        if !ensure_ready(Duration::from_secs(1800), true) {
            log("daemon: Waydroid is not ready");
            return false;
        }
    }
    let _ = install_bundled();
    let _ = sync_entries();
    let _ = ensure_bridge();
    write_state(None, None);
    true
}

fn cmd_daemon(once: bool) -> i32 {
    if let Some(parent) = daemon_pid_path().parent() {
        let _ = fs::create_dir_all(parent);
    }
    let _ = fs::write(daemon_pid_path(), format!("{}\n", std::process::id()));
    log(&format!(
        "supervisor started (pid {}, once={})",
        std::process::id(),
        once
    ));
    if once {
        let ok = daemon_cycle();
        let _ = fs::remove_file(daemon_pid_path());
        return if ok { 0 } else { 1 };
    }
    loop {
        if fs::metadata(pause_path()).is_ok() {
            thread::sleep(Duration::from_secs(30));
            continue;
        }
        if !session_running() {
            if !ensure_ready(Duration::from_secs(1800), true) {
                thread::sleep(Duration::from_secs(60));
                continue;
            }
        }
        let _ = install_bundled();
        let _ = sync_entries();
        write_state(None, None);
        thread::sleep(Duration::from_secs(60));
    }
}

fn cmd_autostart(arguments: &[String]) -> i32 {
    const UNIT: &str = "elvonos-waydroid.service";
    let Some(value) = arguments.first() else {
        let config = load_config();
        println!(
            "autostart={}",
            config.get("autostart").map(String::as_str).unwrap_or("false")
        );
        println!(
            "unit={}",
            if user_unit_active(UNIT) {
                "active"
            } else {
                "inactive"
            }
        );
        return 0;
    };
    let mut config = load_config();
    match value.as_str() {
        "on" | "enable" | "true" => {
            config.insert("autostart".into(), "true".into());
            if let Err(error) = save_config(&config) {
                eprintln!("Could not save configuration: {}", error);
                return 1;
            }
            if user_unit_installed(UNIT) {
                let _ = systemctl_user(&["daemon-reload"]);
                if systemctl_user(&["enable", "--now", UNIT]) {
                    println!("Waydroid will start automatically at login (systemd user service).");
                    return 0;
                }
            }
            println!("Waydroid will start automatically at login (session hook).");
            0
        }
        "off" | "disable" | "false" => {
            config.insert("autostart".into(), "false".into());
            if let Err(error) = save_config(&config) {
                eprintln!("Could not save configuration: {}", error);
                return 1;
            }
            let _ = systemctl_user(&["disable", "--now", UNIT]);
            println!("Waydroid autostart disabled.");
            0
        }
        other => {
            eprintln!("Unknown autostart value: {}", other);
            2
        }
    }
}

fn cmd_autostart_run() -> i32 {
    // A systemd user service is the preferred path; do not start a second
    // supervisor from the session hook when the unit is already active.
    if user_unit_active("elvonos-waydroid.service") {
        return 0;
    }
    if load_config()
        .get("autostart")
        .map(String::as_str)
        .unwrap_or("false")
        != "true"
    {
        return 0;
    }
    cmd_daemon(false)
}

fn cmd_config(arguments: &[String]) -> i32 {
    let mut config = load_config();
    if arguments.is_empty() {
        let mut keys: Vec<&String> = config.keys().collect();
        keys.sort();
        for key in keys {
            println!(
                "{}={}",
                key,
                config.get(key).map(String::as_str).unwrap_or("")
            );
        }
        return 0;
    }
    match arguments[0].as_str() {
        "get" => {
            if let Some(key) = arguments.get(1) {
                println!(
                    "{}",
                    config.get(key).map(String::as_str).unwrap_or("")
                );
                0
            } else {
                2
            }
        }
        "set" => {
            if arguments.len() < 3 {
                return 2;
            }
            config.insert(arguments[1].clone(), arguments[2].clone());
            match save_config(&config) {
                Ok(_) => 0,
                Err(error) => {
                    eprintln!("Could not save configuration: {}", error);
                    1
                }
            }
        }
        other => {
            eprintln!("Unknown config command: {}", other);
            2
        }
    }
}

// ---------------------------------------------------------------------------
// Graphics profile
//
// Waydroid detects gralloc/EGL from the host.  A virtual machine without a
// usable virgl renderer needs a software rasterizer instead, otherwise
// SurfaceFlinger aborts with "output buffer not gpu writeable" as soon as the
// first app window is drawn.  The profile is applied before the container
// starts, because LXC reads these files while generating its session config.

const WAYDROID_CFG: &str = "/var/lib/waydroid/waydroid.cfg";
const WAYDROID_LXC_BASE: &str = "/usr/lib/waydroid/data/configs/config_base";
const GRAPHICS_PIN: &str = "/etc/elvonos/waydroid-graphics";
const SOFTWARE_ENV: &str = "lxc.environment = GALLIUM_DRIVER=llvmpipe";
const GRAPHICS_KEYS: [&str; 4] = [
    "ro.hardware.gralloc",
    "ro.hardware.egl",
    "ro.hardware.vulkan",
    "gralloc.gbm.device",
];

fn graphics_pin() -> Option<String> {
    let text = fs::read_to_string(GRAPHICS_PIN).ok()?;
    let value = text.trim().to_lowercase();
    if value == "software" || value == "gpu" {
        Some(value)
    } else {
        None
    }
}

fn dmi_contains(fragment: &str) -> bool {
    [
        "/sys/class/dmi/id/product_name",
        "/sys/class/dmi/id/sys_vendor",
        "/sys/class/dmi/id/board_vendor",
    ]
    .iter()
    .any(|path| {
        fs::read_to_string(path)
            .map(|value| value.to_lowercase().contains(fragment))
            .unwrap_or(false)
    })
}

fn is_virtual_machine() -> bool {
    [
        "qemu", "kvm", "virtualbox", "vmware", "bochs", "xen", "parallels", "bhyve",
    ]
    .iter()
    .any(|name| dmi_contains(name))
}

fn resolved_graphics_mode() -> String {
    // Only an explicit pin changes the host detection.  The software profile
    // is a diagnostic fallback, not a default: Android's SurfaceFlinger still
    // expects GPU-writable buffers for app windows.
    graphics_pin().unwrap_or_else(|| "gpu".into())
}

fn graphics_reason() -> &'static str {
    if graphics_pin().is_some() {
        "pinned"
    } else if is_virtual_machine() {
        "virtual machine"
    } else {
        "hardware"
    }
}

fn privileged_write(path: &str, contents: &str) -> Result<(), String> {
    let temporary = format!("/tmp/elvonos-waydroid-{}.tmp", std::process::id());
    fs::write(&temporary, contents).map_err(|error| error.to_string())?;
    let status = Command::new("sudo")
        .args(["-n", "install", "-m", "644", &temporary, path])
        .status()
        .map_err(|error| error.to_string())?;
    let _ = fs::remove_file(&temporary);
    if status.success() {
        Ok(())
    } else {
        Err(format!("could not write {}", path))
    }
}

fn rewrite_waydroid_cfg(entries: &[(&str, &str)], remove: &[&str]) -> Result<(), String> {
    let original = fs::read_to_string(WAYDROID_CFG).map_err(|error| error.to_string())?;
    let mut lines: Vec<String> = Vec::new();
    let mut in_properties = false;
    let mut has_properties = false;
    for line in original.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with('[') {
            in_properties = trimmed == "[properties]";
            has_properties |= in_properties;
            lines.push(line.to_string());
            continue;
        }
        if in_properties {
            let key = trimmed.split('=').next().unwrap_or("").trim();
            if remove.iter().any(|item| *item == key)
                || entries.iter().any(|(name, _)| *name == key)
            {
                continue;
            }
        }
        lines.push(line.to_string());
    }
    if !has_properties {
        lines.push(String::new());
        lines.push("[properties]".into());
    }
    let position = lines
        .iter()
        .position(|line| line.trim() == "[properties]")
        .unwrap_or(0);
    let additions: Vec<String> = entries
        .iter()
        .map(|(name, value)| format!("{}={}", name, value))
        .collect();
    lines.splice(position + 1..position + 1, additions);
    let mut body = lines.join("\n");
    body.push('\n');
    privileged_write(WAYDROID_CFG, &body)
}

fn set_software_environment(enabled: bool) -> Result<(), String> {
    let original = fs::read_to_string(WAYDROID_LXC_BASE).map_err(|error| error.to_string())?;
    let mut lines: Vec<String> = original
        .lines()
        .filter(|line| line.trim() != SOFTWARE_ENV)
        .map(str::to_string)
        .collect();
    if enabled {
        lines.push(SOFTWARE_ENV.to_string());
    }
    let mut body = lines.join("\n");
    body.push('\n');
    privileged_write(WAYDROID_LXC_BASE, &body)
}

fn apply_graphics_mode(mode: &str) -> Result<(), String> {
    // Let Waydroid detect gralloc/EGL itself; only the software rasterizer is
    // injected through the container environment.
    rewrite_waydroid_cfg(&[], &GRAPHICS_KEYS)?;
    set_software_environment(mode == "software")
}

fn graphics_description() -> String {
    let pin = graphics_pin().unwrap_or_else(|| "auto".into());
    let mode = resolved_graphics_mode();
    let env = fs::read_to_string(WAYDROID_LXC_BASE)
        .map(|text| text.lines().any(|line| line.trim() == SOFTWARE_ENV))
        .unwrap_or(false);
    format!(
        "pin={} mode={} reason={} software_env={}",
        pin,
        mode,
        graphics_reason(),
        env
    )
}

fn cmd_graphics(arguments: &[String]) -> i32 {
    let action = arguments.first().map(String::as_str).unwrap_or("status");
    match action {
        "status" | "show" => {
            println!("{}", graphics_description());
            0
        }
        "auto" => match privileged_write(GRAPHICS_PIN, "auto\n") {
            Ok(_) => {
                let mode = resolved_graphics_mode();
                match apply_graphics_mode(&mode) {
                    Ok(_) => {
                        println!("graphics=auto ({})", mode);
                        0
                    }
                    Err(error) => {
                        eprintln!("{}", error);
                        1
                    }
                }
            }
            Err(error) => {
                eprintln!("{}", error);
                1
            }
        },
        "software" | "sw" | "gpu" => {
            let mode = if action == "gpu" { "gpu" } else { "software" };
            if let Err(error) = privileged_write(GRAPHICS_PIN, &format!("{}\n", mode)) {
                eprintln!("{}", error);
                return 1;
            }
            match apply_graphics_mode(mode) {
                Ok(_) => {
                    println!("graphics={} (restart Waydroid to apply)", mode);
                    0
                }
                Err(error) => {
                    eprintln!("{}", error);
                    1
                }
            }
        }
        other => {
            eprintln!("Unknown graphics mode: {}", other);
            2
        }
    }
}

// ---------------------------------------------------------------------------
// System integration: clipboard/notification bridge, storage, restart, units

fn bridge_pid_path() -> PathBuf {
    state_dir().join("waydroid-bridge.pid")
}

fn process_alive(pid: u32) -> bool {
    Path::new(&format!("/proc/{}", pid)).exists()
}

fn bridge_running() -> bool {
    fs::read_to_string(bridge_pid_path())
        .ok()
        .and_then(|text| text.trim().parse::<u32>().ok())
        .map(process_alive)
        .unwrap_or(false)
}

fn bridge_enabled() -> bool {
    load_config()
        .get("bridge")
        .map(|value| value != "false" && value != "off")
        .unwrap_or(true)
}

fn ensure_bridge() -> bool {
    if !bridge_enabled() {
        return false;
    }
    if bridge_running() {
        return true;
    }
    if which("elvonos-waydroid-bridge").is_none() {
        return false;
    }
    // setsid detaches the bridge from this process; it writes its own pid file.
    let launched = Command::new("sh")
        .args([
            "-c",
            "setsid elvonos-waydroid-bridge >/dev/null 2>&1 < /dev/null &",
        ])
        .status()
        .map(|status| status.success())
        .unwrap_or(false);
    if launched {
        thread::sleep(Duration::from_millis(400));
        log("clipboard/notification bridge started");
    }
    launched && bridge_running()
}

fn stop_bridge() {
    if let Ok(text) = fs::read_to_string(bridge_pid_path()) {
        if let Ok(pid) = text.trim().parse::<u32>() {
            let _ = Command::new("kill").arg(pid.to_string()).status();
        }
        let _ = fs::remove_file(bridge_pid_path());
    }
    // Also stop stale instances that lost their pid file.  SIGKILL is used
    // because the gbinder threads can keep a normal SIGTERM from exiting.
    let _ = Command::new("pkill")
        .args(["-9", "-f", "elvonos-waydroid-bridge"])
        .status();
}

fn directory_bytes(path: &Path) -> u64 {
    Command::new("du")
        .args(["-sb"])
        .arg(path)
        .output()
        .ok()
        .and_then(|output| {
            String::from_utf8_lossy(&output.stdout)
                .split_whitespace()
                .next()
                .and_then(|value| value.parse::<u64>().ok())
        })
        .unwrap_or(0)
}

fn filesystem_space(path: &Path) -> (u64, u64) {
    let output = Command::new("df")
        .args(["-B1", "--output=size,avail"])
        .arg(path)
        .output();
    let Ok(output) = output else {
        return (0, 0);
    };
    let body = String::from_utf8_lossy(&output.stdout);
    for line in body.lines().skip(1) {
        let fields: Vec<&str> = line.split_whitespace().collect();
        if fields.len() >= 2 {
            if let (Ok(total), Ok(free)) = (fields[0].parse(), fields[1].parse()) {
                return (total, free);
            }
        }
    }
    (0, 0)
}

fn cmd_storage(json: bool) -> i32 {
    let data = data_home().join("waydroid/data");
    let used = directory_bytes(&data);
    let (total, free) = filesystem_space(if data.exists() {
        data.as_path()
    } else {
        Path::new("/")
    });
    let apps = if android_ready() { app_count() } else { 0 };
    let bridge = bridge_running();
    if json {
        println!(
            "{{\"data\":\"{}\",\"used\":{},\"total\":{},\"free\":{},\"apps\":{},\"bridge\":{},\"running\":{}}}",
            json_escape(&data.display().to_string()),
            used,
            total,
            free,
            apps,
            bridge,
            session_running()
        );
    } else {
        println!("Data directory: {}", data.display());
        println!("Android data:   {:.1} MiB", used as f64 / 1048576.0);
        println!(
            "Free space:     {:.1} GiB of {:.1} GiB",
            free as f64 / 1073741824.0,
            total as f64 / 1073741824.0
        );
        println!("Android apps:   {}", apps);
        println!(
            "Bridge:         {}",
            if bridge {
                "running"
            } else {
                "stopped"
            }
        );
    }
    0
}

fn cmd_bridge(arguments: &[String]) -> i32 {
    match arguments.first().map(String::as_str).unwrap_or("status") {
        "start" => {
            if ensure_bridge() {
                println!("Waydroid bridge started.");
                0
            } else {
                eprintln!("Waydroid bridge could not be started.");
                1
            }
        }
        "stop" => {
            stop_bridge();
            println!("Waydroid bridge stopped.");
            0
        }
        "status" => {
            println!(
                "bridge={}",
                if bridge_running() { "running" } else { "stopped" }
            );
            0
        }
        other => {
            eprintln!("Unknown bridge command: {}", other);
            2
        }
    }
}

fn cmd_restart() -> i32 {
    log("restart requested");
    stop_bridge();
    if let Ok(text) = fs::read_to_string(session_pid_path()) {
        if let Ok(pid) = text.trim().parse::<u32>() {
            let _ = Command::new("kill").arg(pid.to_string()).status();
        }
        let _ = fs::remove_file(session_pid_path());
    }
    let _ = stop_container();
    for _ in 0..20 {
        if !container_active() {
            break;
        }
        thread::sleep(Duration::from_millis(250));
    }
    thread::sleep(Duration::from_secs(2));
    let _ = fs::remove_file(pause_path());
    if ensure_ready(Duration::from_secs(1800), true) {
        println!("Waydroid restarted.");
        0
    } else {
        eprintln!("Waydroid could not be restarted.");
        1
    }
}

fn cmd_clear_data(package: &str) -> i32 {
    if !android_ready() {
        eprintln!("Android is not running.");
        return 1;
    }
    match lxc(&["pm", "clear", package]) {
        Some(output) if text(&output).contains("Success") => {
            log(&format!("cleared app data for {}", package));
            println!("Data cleared for {}.", package);
            0
        }
        Some(output) => {
            eprintln!("{}", text(&output).trim());
            1
        }
        None => {
            eprintln!("Could not clear data for {}.", package);
            1
        }
    }
}

fn systemctl_user(arguments: &[&str]) -> bool {
    Command::new("systemctl")
        .arg("--user")
        .args(arguments)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|status| status.success())
        .unwrap_or(false)
}

fn user_unit_active(unit: &str) -> bool {
    Command::new("systemctl")
        .args(["--user", "is-active", "--quiet", unit])
        .status()
        .map(|status| status.success())
        .unwrap_or(false)
}

fn user_unit_installed(unit: &str) -> bool {
    [
        "/usr/lib/systemd/user".to_string(),
        "/etc/systemd/user".to_string(),
        format!(
            "{}/.config/systemd/user",
            home().display()
        ),
    ]
    .iter()
    .any(|directory| Path::new(directory).join(unit).is_file())
}

// ---------------------------------------------------------------------------
// Intents, sharing and power integration

fn container_state() -> Option<String> {
    let output = Command::new("sudo")
        .args(["-n", "lxc-info", "-P", LXC_PATH, "-n", LXC_NAME, "-s"])
        .output()
        .ok()?;
    let body = String::from_utf8_lossy(&output.stdout);
    for line in body.lines() {
        if let Some((key, value)) = line.split_once(':') {
            if key.trim().eq_ignore_ascii_case("State") {
                return Some(value.trim().to_uppercase());
            }
        }
    }
    None
}

fn set_frozen(unfreeze: bool) -> bool {
    let method = if unfreeze { "Unfreeze" } else { "Freeze" };
    if let Ok(system) = Connection::new_system() {
        let proxy = system.with_proxy(
            "id.waydro.Container",
            "/ContainerManager",
            Duration::from_secs(30),
        );
        let result: Result<(), _> =
            proxy.method_call("id.waydro.ContainerManager", method, ());
        if result.is_ok() {
            return true;
        }
    }
    let action = if unfreeze { "unfreeze" } else { "freeze" };
    Command::new("waydroid")
        .args(["container", action])
        .status()
        .map(|status| status.success())
        .unwrap_or(false)
}

fn cmd_freeze(unfreeze: bool) -> i32 {
    if !session_running() {
        eprintln!("Waydroid session is not running.");
        return 1;
    }
    if set_frozen(unfreeze) {
        log(if unfreeze {
            "container unfrozen"
        } else {
            "container frozen"
        });
        println!(
            "Waydroid {}.",
            if unfreeze { "unfrozen" } else { "frozen" }
        );
        0
    } else {
        eprintln!(
            "Waydroid could not be {}.",
            if unfreeze { "unfrozen" } else { "frozen" }
        );
        1
    }
}

fn mime_for(path: &Path) -> String {
    if which("xdg-mime").is_some() {
        if let Ok(output) = Command::new("xdg-mime")
            .arg("query")
            .arg("filetype")
            .arg(path)
            .output()
        {
            let value = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if !value.is_empty() {
                return value;
            }
        }
    }
    let extension = path
        .extension()
        .and_then(|value| value.to_str())
        .unwrap_or("")
        .to_lowercase();
    match extension.as_str() {
        "pdf" => "application/pdf",
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "gif" => "image/gif",
        "webp" => "image/webp",
        "mp4" => "video/mp4",
        "mkv" => "video/x-matroska",
        "mp3" => "audio/mpeg",
        "ogg" => "audio/ogg",
        "txt" => "text/plain",
        "html" | "htm" => "text/html",
        "epub" => "application/epub+zip",
        "zip" => "application/zip",
        "apk" => "application/vnd.android.package-archive",
        _ => "application/octet-stream",
    }
    .to_string()
}

fn parse_media_id(body: &str) -> Option<String> {
    for line in body.lines() {
        if let Some(position) = line.find("_id=") {
            let digits: String = line[position + 4..]
                .chars()
                .take_while(|character| character.is_ascii_digit())
                .collect();
            if !digits.is_empty() {
                return Some(digits);
            }
        }
    }
    None
}

fn cmd_share(value: &str) -> i32 {
    if value.is_empty() {
        eprintln!("Nothing to share.");
        return 2;
    }
    if container_state().as_deref() == Some("FROZEN") {
        eprintln!("Android is frozen; run 'elvonos-waydroid unfreeze' first.");
        return 1;
    }
    if !android_ready() {
        eprintln!("Android is not running.");
        return 1;
    }
    let result = lxc(&[
        "am",
        "start",
        "-a",
        "android.intent.action.SEND",
        "-t",
        "text/plain",
        "--es",
        "android.intent.extra.TEXT",
        value,
    ]);
    match result {
        Some(output) => {
            let body = text(&output);
            if body.to_lowercase().contains("error") {
                eprintln!("{}", body.trim());
                1
            } else {
                0
            }
        }
        None => 1,
    }
}

fn cmd_open(path: &Path) -> i32 {
    if !path.is_file() {
        eprintln!("Not a file: {}", path.display());
        return 2;
    }
    if container_state().as_deref() == Some("FROZEN") {
        eprintln!("Android is frozen; run 'elvonos-waydroid unfreeze' first.");
        return 1;
    }
    if !android_ready() {
        eprintln!("Android is not running.");
        return 1;
    }
    let Some(name) = path.file_name().and_then(|value| value.to_str()) else {
        return 2;
    };
    let download = data_home().join("waydroid/data/media/0/Download");
    // The Android data directory is owned by the container's media user; the
    // desktop user cannot write it directly.
    let directory_status = Command::new("sudo")
        .args(["-n", "mkdir", "-p"])
        .arg(&download)
        .status();
    if directory_status.map(|value| !value.success()).unwrap_or(true) {
        eprintln!("Could not create {}", download.display());
        return 1;
    }
    let target = download.join(name);
    let copy_status = Command::new("sudo")
        .args(["-n", "cp", "--"])
        .arg(path)
        .arg(&target)
        .status();
    if copy_status.map(|value| !value.success()).unwrap_or(true) {
        eprintln!("Could not copy to Android storage.");
        return 1;
    }
    let _ = Command::new("sudo")
        .args(["-n", "chown", "--reference"])
        .arg(&download)
        .arg(&target)
        .status();
    let _ = Command::new("sudo")
        .args(["-n", "chmod", "0660"])
        .arg(&target)
        .status();
    let android_path = format!("/storage/emulated/0/Download/{}", name);
    let mime = mime_for(path);
    let _ = lxc(&[
        "am",
        "broadcast",
        "-a",
        "android.intent.action.MEDIA_SCANNER_SCAN_FILE",
        "-d",
        &format!("file://{}", android_path),
    ]);
    thread::sleep(Duration::from_millis(900));
    let media_id = lxc(&[
        "content",
        "query",
        "--uri",
        "content://media/external/file",
        "--projection",
        "_id",
        "--where",
        &format!("_data='{}'", android_path),
    ])
    .map(|output| text(&output))
    .and_then(|body| parse_media_id(&body));
    let uri = media_id
        .map(|id| format!("content://media/external/file/{}", id))
        .unwrap_or_else(|| format!("file://{}", android_path));
    let result = lxc(&[
        "am",
        "start",
        "-a",
        "android.intent.action.VIEW",
        "-d",
        &uri,
        "-t",
        &mime,
        "--grant-read-uri-permission",
    ]);
    match result {
        Some(output) => {
            let body = text(&output);
            if body.to_lowercase().contains("error") {
                eprintln!("{}", body.trim());
                1
            } else {
                println!("Opened {} in Android.", name);
                0
            }
        }
        None => 1,
    }
}

// ---------------------------------------------------------------------------
// Backup and restore of the Android data directory

fn compact_timestamp() -> String {
    Command::new("date")
        .arg("+%Y%m%d-%H%M%S")
        .output()
        .ok()
        .map(|output| String::from_utf8_lossy(&output.stdout).trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "backup".into())
}

fn cmd_backup(target: Option<&str>) -> i32 {
    let destination = match target {
        Some(value) if !value.is_empty() => PathBuf::from(value),
        _ => home()
            .join("Backups")
            .join(format!("waydroid-{}.tar.zst", compact_timestamp())),
    };
    if let Some(parent) = destination.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let data = data_home().join("waydroid");
    if !data.join("data").is_dir() {
        eprintln!("No Android data directory found at {}", data.display());
        return 1;
    }
    // A frozen container gives a consistent snapshot.
    let was_frozen = container_state().as_deref() == Some("FROZEN");
    let freeze = !was_frozen && session_running();
    if freeze && !set_frozen(false) {
        log("backup: could not freeze the container; copying anyway");
    }
    let status = Command::new("sudo")
        .args(["-n", "tar", "--zstd", "-cf"])
        .arg(&destination)
        .arg("-C")
        .arg(&data)
        .arg("data")
        .status();
    if freeze {
        let _ = set_frozen(true);
    }
    match status {
        Ok(value) if value.success() => {
            log(&format!("backup written to {}", destination.display()));
            println!("Backup written to {}", destination.display());
            0
        }
        _ => {
            eprintln!("Could not write the backup.");
            1
        }
    }
}

fn cmd_restore(source: &str) -> i32 {
    let mut selection = source.trim().to_string();
    if selection.is_empty() {
        let Some(zenity) = which("zenity") else {
            eprintln!("Usage: elvonos-waydroid restore FILE");
            return 2;
        };
        let output = Command::new(zenity)
            .args([
                "--file-selection",
                "--title=Android data backup",
                "--file-filter=Android backup (*.tar.zst) | *.tar.zst",
            ])
            .arg(format!("--filename={}/", home().join("Backups").display()))
            .output();
        let Ok(output) = output else {
            return 2;
        };
        if !output.status.success() {
            return 0;
        }
        selection = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if selection.is_empty() {
            return 0;
        }
    }
    let archive = PathBuf::from(&selection);
    if !archive.is_file() {
        eprintln!("Backup not found: {}", selection);
        return 1;
    }
    log(&format!("restoring {}", archive.display()));
    stop_bridge();
    if let Ok(text) = fs::read_to_string(session_pid_path()) {
        if let Ok(pid) = text.trim().parse::<u32>() {
            let _ = Command::new("kill").arg(pid.to_string()).status();
        }
        let _ = fs::remove_file(session_pid_path());
    }
    let _ = stop_container();
    for _ in 0..40 {
        if !container_active() {
            break;
        }
        thread::sleep(Duration::from_millis(250));
    }
    thread::sleep(Duration::from_secs(2));
    let data = data_home().join("waydroid");
    let _ = fs::create_dir_all(&data);
    let status = Command::new("sudo")
        .args(["-n", "tar", "--zstd", "-xf"])
        .arg(&archive)
        .arg("-C")
        .arg(&data)
        .status();
    if !status.map(|value| value.success()).unwrap_or(false) {
        eprintln!("Could not extract the backup.");
        return 1;
    }
    let _ = fs::remove_file(pause_path());
    if ensure_ready(Duration::from_secs(1800), true) {
        println!("Restored {}.", selection);
        0
    } else {
        eprintln!("Restore finished, but Waydroid did not start.");
        1
    }
}

// ---------------------------------------------------------------------------
// Multi-window control

fn cmd_multiwindow(arguments: &[String]) -> i32 {
    let value = arguments.first().map(String::as_str).unwrap_or("status");
    if value == "status" {
        let current = load_config()
            .get("multiwindow")
            .cloned()
            .unwrap_or_else(|| "true".into());
        println!("multiwindow={}", current);
        return 0;
    }
    let enabled = matches!(value, "on" | "enable" | "true" | "1");
    let disabled = matches!(value, "off" | "disable" | "false" | "0");
    if !enabled && !disabled {
        eprintln!("Usage: elvonos-waydroid multiwindow on|off");
        return 2;
    }
    let mut config = load_config();
    config.insert(
        "multiwindow".into(),
        if enabled { "true" } else { "false" }.into(),
    );
    if let Err(error) = save_config(&config) {
        eprintln!("Could not save configuration: {}", error);
        return 1;
    }
    if android_ready() {
        let _ = lxc(&[
            "setprop",
            "persist.waydroid.multi_windows",
            if enabled { "true" } else { "false" },
        ]);
    }
    println!(
        "Multi-window {} (restart Waydroid to apply).",
        if enabled { "enabled" } else { "disabled" }
    );
    0
}
