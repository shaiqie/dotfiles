use std::ffi::OsString;
use std::process::ExitCode;

use crate::commands::panel::Panel;
use crate::commands::ShellCommand;
use crate::core::args::Args;
use crate::core::context::Context;
use crate::core::process::Proc;
use crate::ui::log;

pub struct Clipboard;

impl ShellCommand for Clipboard {
    fn run(&self, ctx: &Context, mut args: Args) -> ExitCode {
        match args.next_string().as_deref() {
            Some(action @ ("toggle" | "open" | "close")) => {
                Panel::new("clipboard").run(ctx, Args::new(vec![OsString::from(action)]))
            }
            Some("pick") | None => pick(ctx),
            Some(other) => {
                log::err(&format!("unknown clipboard command `{other}`"));
                log::hint("use pick, toggle, open, close");
                ExitCode::from(2)
            }
        }
    }
}

fn pick(ctx: &Context) -> ExitCode {
    let Some(raw_list) = Proc::output("cliphist", ["list"]) else {
        log::err("cliphist list failed");
        return ExitCode::from(1);
    };

    let mut pairs: Vec<(String, String)> = Vec::new();
    for raw in raw_list.lines().filter(|line| !line.trim().is_empty()) {
        let preview = raw
            .splitn(2, char::is_whitespace)
            .nth(1)
            .unwrap_or(raw)
            .trim();
        pairs.push((format!("󰅇  {preview}"), raw.to_string()));
    }

    if pairs.is_empty() {
        log::hint("clipboard history empty");
        return ExitCode::SUCCESS;
    }

    let input = pairs
        .iter()
        .map(|(display, _)| display.as_str())
        .collect::<Vec<_>>()
        .join("\n");
    let theme = ctx.paths.home.join(".config/rofi/spotlight.rasi");
    let picked = Proc::pipe(
        "rofi",
        &[
            "-dmenu",
            "-p",
            " ",
            "-config",
            &theme.to_string_lossy(),
            "-l",
            "3",
            "-i",
        ],
        input.as_bytes(),
    )
    .unwrap_or_default()
    .trim()
    .to_string();

    if picked.is_empty() {
        return ExitCode::SUCCESS;
    }

    let Some((_, raw)) = pairs.iter().find(|(display, _)| display == &picked) else {
        log::err("clipboard selection not found");
        return ExitCode::from(1);
    };

    let Some(decoded) = Proc::pipe_bytes("cliphist", &["decode"], raw.as_bytes()) else {
        log::err("cliphist decode failed");
        return ExitCode::from(1);
    };

    if !Proc::write_stdin("wl-copy", &[], &decoded) {
        log::err("wl-copy failed");
        return ExitCode::from(1);
    }

    Proc::quiet_status("notify-send", ["Clipboard", "Copied selected entry."]);
    log::good("clipboard copied");
    ExitCode::SUCCESS
}
