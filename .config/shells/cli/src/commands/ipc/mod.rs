use std::process::ExitCode;

use crate::commands::ShellCommand;
use crate::core::args::Args;
use crate::core::context::Context;
use crate::core::process::Proc;
use crate::ui::log;

pub struct Ipc;

impl ShellCommand for Ipc {
    fn run(&self, _ctx: &Context, mut args: Args) -> ExitCode {
        match args.next_string().as_deref() {
            Some("call") => {
                let target = args.next_string();
                let function = args.next_string();
                match (target, function) {
                    (Some(target), Some(function)) => call(&target, &function, args),
                    _ => {
                        log::err("usage: shell ipc call <target> <function> [args...]");
                        ExitCode::from(2)
                    }
                }
            }
            _ => {
                log::err("usage: shell ipc call <target> <function> [args...]");
                ExitCode::from(2)
            }
        }
    }
}

pub fn call(target: &str, function: &str, args: Args) -> ExitCode {
    let mut argv = vec!["ipc".into(), "call".into(), target.into(), function.into()];
    argv.extend(Proc::os_args(args.rest()));
    let code = Proc::status("quickshell", argv);
    if code == ExitCode::SUCCESS {
        log::good(&format!("ipc {target}.{function}"));
    }
    code
}
