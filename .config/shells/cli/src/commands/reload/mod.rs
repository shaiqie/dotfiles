use std::process::ExitCode;
use std::thread;
use std::time::Duration;

use crate::commands::ShellCommand;
use crate::core::args::Args;
use crate::core::context::Context;
use crate::core::process::Proc;
use crate::ui::log;

pub struct Reload;

impl ShellCommand for Reload {
    fn run(&self, ctx: &Context, mut args: Args) -> ExitCode {
        match args.next_string().as_deref() {
            Some("soft") => soft_reload(),
            Some("full") | None => full_reload(ctx),
            Some(other) => {
                log::err(&format!("unknown reload mode `{other}`"));
                log::hint("use `shell reload`, or `shell reload soft`");
                ExitCode::from(2)
            }
        }
    }
}

fn soft_reload() -> ExitCode {
    let code = Proc::status("quickshell", ["reload"]);
    if code == ExitCode::SUCCESS {
        log::good("quickshell reload sent");
    }
    code
}

fn full_reload(ctx: &Context) -> ExitCode {
    Proc::quiet_status("pkill", ["quickshell"]);
    thread::sleep(Duration::from_millis(500));

    let path = ctx.paths.config_dir.to_string_lossy().to_string();
    Proc::spawn("quickshell", ["--path", &path, "--no-duplicate"]);
    Proc::quiet_status("wal", ["-R"]);
    Proc::quiet_status("hyprctl", ["reload"]);

    for _ in 0..20 {
        if Proc::quiet_status(
            "dbus-send",
            [
                "--session",
                "--print-reply",
                "--dest=org.freedesktop.DBus",
                "/org/freedesktop/DBus",
                "org.freedesktop.DBus.GetNameOwner",
                "string:org.freedesktop.Notifications",
            ],
        ) {
            break;
        }
        thread::sleep(Duration::from_millis(300));
    }

    thread::sleep(Duration::from_millis(300));
    Proc::quiet_status(
        "notify-send",
        [
            "System Reloaded",
            "System-related environment has been reloaded.",
        ],
    );
    log::good("full reload done");
    ExitCode::SUCCESS
}
