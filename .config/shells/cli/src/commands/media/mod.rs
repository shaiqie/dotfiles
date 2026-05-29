use std::path::PathBuf;
use std::process::ExitCode;

use crate::commands::ShellCommand;
use crate::core::args::Args;
use crate::core::context::Context;
use crate::core::process::Proc;
use crate::ui::log;

pub struct Media;

impl ShellCommand for Media {
    fn run(&self, ctx: &Context, mut args: Args) -> ExitCode {
        match args.next_string().as_deref() {
            Some("lock-info") | None => lock_info(ctx),
            Some(other) => {
                log::err(&format!("unknown media command `{other}`"));
                log::hint("use lock-info");
                ExitCode::from(2)
            }
        }
    }
}

fn lock_info(_ctx: &Context) -> ExitCode {
    let status = Proc::output("playerctl", ["status"])
        .unwrap_or_default()
        .trim()
        .to_string();
    if status.is_empty() || status.eq_ignore_ascii_case("stopped") {
        println!();
        return ExitCode::SUCCESS;
    }

    let title = metadata("{{title}}", "No title");
    let artist = metadata("{{artist}}", "Unknown artist");
    let art = metadata("{{mpris:artUrl}}", "");
    let cover = PathBuf::from("/tmp/hyprlock_cover.png");

    if let Some(path) = art.strip_prefix("file://") {
        Proc::quiet_status(
            "convert",
            [
                path,
                "-gravity",
                "center",
                "-background",
                "none",
                "-extent",
                "1:1",
                &cover.to_string_lossy(),
            ],
        );
    } else if art.starts_with("http://") || art.starts_with("https://") {
        let tmp = "/tmp/hyprlock_cover_src";
        Proc::quiet_status("curl", ["-sL", "-o", tmp, art.as_str()]);
        Proc::quiet_status(
            "convert",
            [
                tmp,
                "-gravity",
                "center",
                "-background",
                "none",
                "-extent",
                "1:1",
                &cover.to_string_lossy(),
            ],
        );
    } else {
        Proc::quiet_status(
            "convert",
            ["-size", "1x1", "xc:#0b0b0b", &cover.to_string_lossy()],
        );
    }

    println!("{}", fold_lines(&title, 25, 2));
    println!("{}", fold_lines(&artist, 25, 2));
    ExitCode::SUCCESS
}

fn metadata(format: &str, fallback: &str) -> String {
    Proc::output("playerctl", ["metadata", "--format", format])
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| fallback.to_string())
}

fn fold_lines(text: &str, width: usize, max_lines: usize) -> String {
    let mut lines = Vec::new();
    let mut line = String::new();

    for word in text.split_whitespace() {
        if !line.is_empty() && line.len() + word.len() + 1 > width {
            lines.push(line);
            line = String::new();
            if lines.len() == max_lines {
                break;
            }
        }
        if !line.is_empty() {
            line.push(' ');
        }
        line.push_str(word);
    }

    if !line.is_empty() && lines.len() < max_lines {
        lines.push(line);
    }

    if lines.is_empty() {
        text.chars().take(width).collect()
    } else {
        lines.join("\n")
    }
}
