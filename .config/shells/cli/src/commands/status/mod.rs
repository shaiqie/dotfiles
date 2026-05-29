use std::process::ExitCode;

use crate::commands::ShellCommand;
use crate::core::args::Args;
use crate::core::context::Context;
use crate::core::process::Proc;
use crate::ui::log;

pub struct Status;

impl ShellCommand for Status {
    fn run(&self, ctx: &Context, _args: Args) -> ExitCode {
        log::line(
            "config",
            &ctx.paths.shell_qml().display().to_string(),
            ctx.paths.shell_qml().is_file(),
        );
        log::line(
            "cache",
            &ctx.paths.cache_dir.display().to_string(),
            ctx.paths.cache_dir.is_dir(),
        );
        log::line(
            "wallpapers",
            &ctx.paths.wallpaper_dir.display().to_string(),
            ctx.paths.wallpaper_dir.is_dir(),
        );
        log::line(
            "quickshell",
            &Proc::tool_version("quickshell"),
            Proc::tool_exists("quickshell"),
        );
        log::line(
            "hyprctl",
            &Proc::tool_version("hyprctl"),
            Proc::tool_exists("hyprctl"),
        );
        log::line("wal", &Proc::tool_version("wal"), Proc::tool_exists("wal"));
        ExitCode::SUCCESS
    }
}
