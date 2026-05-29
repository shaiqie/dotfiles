use std::ffi::OsString;
use std::fs;
use std::os::unix::fs as unix_fs;
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::time::{SystemTime, UNIX_EPOCH};

use crate::commands::ShellCommand;
use crate::core::args::Args;
use crate::core::context::Context;
use crate::core::process::Proc;
use crate::ui::log;

pub struct Wallpaper;

impl ShellCommand for Wallpaper {
    fn run(&self, ctx: &Context, mut args: Args) -> ExitCode {
        match args.next_string().as_deref() {
            Some("apply") => match args.next_string() {
                Some(name) => apply(ctx, &name),
                None => {
                    log::err("usage: shell wallpaper apply <file|name>");
                    ExitCode::from(2)
                }
            },
            Some("list") => list(ctx),
            Some("select") => select(ctx),
            Some(action @ ("toggle" | "open" | "close")) => {
                let mut pass = Vec::new();
                pass.push(OsString::from(action));
                crate::commands::panel::Panel::new("wallpaper").run(ctx, Args::new(pass))
            }
            None => {
                let mut pass = Vec::new();
                pass.push(OsString::from("toggle"));
                crate::commands::panel::Panel::new("wallpaper").run(ctx, Args::new(pass))
            }
            Some(other) => {
                log::err(&format!("unknown wallpaper command `{other}`"));
                log::hint("use apply, list, select, toggle, open, close");
                ExitCode::from(2)
            }
        }
    }
}

fn apply(ctx: &Context, input: &str) -> ExitCode {
    let wall = resolve_wallpaper(ctx, input);
    if !wall.is_file() {
        log::err(&format!("wallpaper not found: {}", wall.display()));
        return ExitCode::from(1);
    }

    let transition = ["wipe", "outer", "center"][random_index(3)];
    log::info(&format!("wallpaper {}", wall.display()));
    log::info(&format!("transition {transition}"));

    Proc::status(
        "wal",
        [OsString::from("-i"), wall.as_os_str().to_os_string()],
    );
    Proc::status(
        "awww",
        [
            OsString::from("img"),
            wall.as_os_str().to_os_string(),
            OsString::from("--transition-type"),
            OsString::from(transition),
            OsString::from("--transition-pos"),
            OsString::from("center"),
            OsString::from("--transition-step"),
            OsString::from("255"),
            OsString::from("--transition-fps"),
            OsString::from("144"),
            OsString::from("--transition-bezier"),
            OsString::from(".42,0,.58,1"),
        ],
    );

    std::thread::sleep(std::time::Duration::from_millis(500));
    sync_theme(ctx);
    Proc::quiet_status(
        "notify-send",
        ["Wallpaper applied", "Theme colors have been synced."],
    );
    log::good("wallpaper applied");
    ExitCode::SUCCESS
}

fn list(ctx: &Context) -> ExitCode {
    for path in wallpapers(ctx) {
        println!("{}", path.file_name().unwrap_or_default().to_string_lossy());
    }
    ExitCode::SUCCESS
}

fn select(ctx: &Context) -> ExitCode {
    let mut input = String::new();
    for path in wallpapers(ctx) {
        let name = path.file_name().unwrap_or_default().to_string_lossy();
        input.push_str(&format!("{name}\0icon\x1f{}\n", path.display()));
    }

    let theme = ctx.paths.home.join(".config/rofi/wallify.rasi");
    let picked = Proc::pipe(
        "rofi",
        &[
            "-dmenu",
            "-i",
            "-theme",
            &theme.to_string_lossy(),
            "-markup-rows",
        ],
        input.as_bytes(),
    )
    .unwrap_or_default()
    .trim()
    .to_string();

    if picked.is_empty() {
        return ExitCode::SUCCESS;
    }
    apply(ctx, &picked)
}

fn resolve_wallpaper(ctx: &Context, input: &str) -> PathBuf {
    let raw = PathBuf::from(input);
    if raw.is_file() {
        raw
    } else {
        ctx.paths.wallpaper_dir.join(input)
    }
}

fn wallpapers(ctx: &Context) -> Vec<PathBuf> {
    let mut out = Vec::new();
    if let Ok(read) = fs::read_dir(&ctx.paths.wallpaper_dir) {
        for item in read.flatten() {
            let path = item.path();
            let ext = path
                .extension()
                .and_then(|e| e.to_str())
                .unwrap_or("")
                .to_ascii_lowercase();
            if matches!(ext.as_str(), "png" | "jpg" | "jpeg" | "webp") {
                out.push(path);
            }
        }
    }
    out.sort();
    out
}

fn sync_theme(ctx: &Context) {
    symlink_force(
        &ctx.paths.home.join(".cache/wal/discord.theme.css"),
        &ctx.paths
            .home
            .join(".config/vesktop/themes/system24.theme.css"),
    );
    Proc::quiet_status(
        "gsettings",
        [
            "set",
            "org.gnome.desktop.interface",
            "color-scheme",
            "prefer-dark",
        ],
    );

    let osd_dir = ctx.paths.home.join(".config/swayosd");
    let _ = fs::create_dir_all(&osd_dir);
    symlink_force(
        &ctx.paths.home.join(".cache/wal/swayosd.css"),
        &osd_dir.join("style.css"),
    );
    Proc::quiet_status("pkill", ["swayosd-server"]);
    Proc::spawn(
        "swayosd-server",
        ["--style", &osd_dir.join("style.css").to_string_lossy()],
    );

    let qt5 = ctx.paths.home.join(".config/qt5ct/colors");
    let qt6 = ctx.paths.home.join(".config/qt6ct/colors");
    let _ = fs::create_dir_all(&qt5);
    let _ = fs::create_dir_all(&qt6);
    let wal_qt = ctx.paths.home.join(".cache/wal/colors-qt.conf");
    symlink_force(&wal_qt, &qt5.join("Pywal.conf"));
    symlink_force(&wal_qt, &qt6.join("Pywal.conf"));

    Proc::quiet_status("pkill", ["snappy-switcher"]);
    Proc::quiet_status("pkill", ["-USR1", "cava"]);
    Proc::spawn("snappy-switcher", ["--daemon"]);
}

fn symlink_force(from: &Path, to: &Path) {
    if let Some(parent) = to.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let _ = fs::remove_file(to);
    let _ = unix_fs::symlink(from, to);
}

fn random_index(max: usize) -> usize {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.subsec_nanos())
        .unwrap_or(0);
    (nanos as usize) % max
}
