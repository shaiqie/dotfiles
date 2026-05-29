mod commands;
mod core;
mod ui;

use std::env;
use std::process::ExitCode;

use commands::Router;
use core::context::Context;

fn main() -> ExitCode {
    let ctx = Context::new();
    Router::run(&ctx, env::args_os().skip(1).collect())
}
