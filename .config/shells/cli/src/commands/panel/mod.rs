use std::process::ExitCode;

use crate::commands::ipc;
use crate::commands::ShellCommand;
use crate::core::args::Args;
use crate::core::context::Context;

pub struct Panel {
    target: &'static str,
}

impl Panel {
    pub fn new(target: &'static str) -> Self {
        Self { target }
    }
}

impl ShellCommand for Panel {
    fn run(&self, _ctx: &Context, mut args: Args) -> ExitCode {
        let function = args.next_string().unwrap_or_else(|| "toggle".to_string());
        ipc::call(self.target, &function, args)
    }
}
