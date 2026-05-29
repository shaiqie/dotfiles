use std::process::ExitCode;

use crate::commands::ShellCommand;
use crate::core::args::Args;
use crate::core::context::Context;
use crate::ui::log;

pub struct Version;

impl ShellCommand for Version {
    fn run(&self, _ctx: &Context, _args: Args) -> ExitCode {
        log::info(&format!("shell {}", env!("CARGO_PKG_VERSION")));
        ExitCode::SUCCESS
    }
}
