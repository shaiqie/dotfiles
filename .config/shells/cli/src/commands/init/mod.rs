use std::fs;
use std::process::ExitCode;

use crate::commands::ShellCommand;
use crate::core::args::Args;
use crate::core::context::Context;
use crate::core::process::Proc;
use crate::ui::log;

pub struct Init;

impl ShellCommand for Init {
    fn run(&self, ctx: &Context, _args: Args) -> ExitCode {
        let mut ok = true;
        ok &= ensure(&ctx.paths.cache_dir);
        ok &= ensure(&ctx.paths.quickshell_cache_dir);

        log::line(
            "config",
            &ctx.paths.config_dir.display().to_string(),
            ctx.paths.config_dir.is_dir(),
        );
        log::line(
            "cache",
            &ctx.paths.cache_dir.display().to_string(),
            ctx.paths.cache_dir.is_dir(),
        );
        log::line(
            "quickshell",
            &Proc::tool_version("quickshell"),
            Proc::tool_exists("quickshell"),
        );

        if !ctx.paths.shell_qml().is_file() {
            log::err(&format!("missing {}", ctx.paths.shell_qml().display()));
            return ExitCode::from(1);
        }

        if !Proc::tool_exists("quickshell") {
            log::err("quickshell missing");
            return ExitCode::from(127);
        }

        if ok {
            let path = ctx.paths.config_dir.to_string_lossy().to_string();
            if Proc::spawn("quickshell", ["--path", &path, "--no-duplicate"]) {
                log::good("shell started");
                ExitCode::SUCCESS
            } else {
                log::err("failed to start quickshell");
                ExitCode::from(1)
            }
        } else {
            log::err("init failed");
            ExitCode::from(1)
        }
    }
}

fn ensure(path: &std::path::Path) -> bool {
    match fs::create_dir_all(path) {
        Ok(()) => true,
        Err(error) => {
            log::err(&format!("mkdir {}: {error}", path.display()));
            false
        }
    }
}
