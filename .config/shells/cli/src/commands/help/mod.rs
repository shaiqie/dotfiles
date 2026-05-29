use std::process::ExitCode;

use crate::commands::ShellCommand;
use crate::core::args::Args;
use crate::core::context::Context;
use crate::ui::log::C;

pub struct Help;

impl ShellCommand for Help {
    fn run(&self, _ctx: &Context, _args: Args) -> ExitCode {
        println!(
            "{bold}{blue}shell{reset} {dim}v{version}{reset}

{bold}Usage{reset}
  {cyan}shell{reset} {green}<command>{reset} [args]

{bold}Core{reset}
  {cyan}shell reload{reset}                     full shell/hypr/pywal reload
  {cyan}shell status{reset}                     show config/tool status
  {cyan}shell init{reset}                       start Quickshell config
  {cyan}shell process{reset}                    list running Quickshell processes
  {cyan}shell process stop{reset} <pid>         stop one Quickshell process
  {cyan}shell ipc call{reset} <target> <fn>     raw Quickshell IPC

{bold}Panels{reset}
  {cyan}shell settings{reset} toggle|open|close
  {cyan}shell launcher{reset} toggle|open|close
  {cyan}shell recorder{reset} toggle|open|close
  {cyan}shell wallpaper{reset} toggle|open|close
  {cyan}shell power{reset} toggle|open|close

{bold}Built-in tools{reset}
  {cyan}shell wallpaper apply{reset} <file|name>     replace old change-wallpaper
  {cyan}shell wallpaper select{reset}                replace old wallify
  {cyan}shell clipboard pick{reset}                  replace old clippy
  {cyan}shell emoji pick{reset}                      replace old emojify
  {cyan}shell media lock-info{reset}                 replace old rhythm
  {cyan}shell workspace switch{reset}                replace old tabby

{bold}Examples{reset}
  {dim}shell ipc call recorder toggle{reset}
  {dim}shell process stop 12345{reset}
  {dim}shell wallpaper apply city.png{reset}
  {dim}shell clipboard pick{reset}",
            bold = C::BOLD,
            blue = C::BLUE,
            green = C::GREEN,
            cyan = C::CYAN,
            dim = C::DIM,
            reset = C::RESET,
            version = env!("CARGO_PKG_VERSION"),
        );
        ExitCode::SUCCESS
    }
}
