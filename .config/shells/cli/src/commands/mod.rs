pub mod clipboard;
pub mod emoji;
pub mod help;
pub mod init;
pub mod ipc;
pub mod media;
pub mod panel;
pub mod process;
pub mod reload;
pub mod status;
pub mod version;
pub mod wallpaper;
pub mod workspace;

use std::ffi::OsString;
use std::process::ExitCode;

use crate::core::args::Args;
use crate::core::context::Context;
use crate::ui::log;

pub trait ShellCommand {
    fn run(&self, ctx: &Context, args: Args) -> ExitCode;
}

pub struct Router;

impl Router {
    pub fn run(ctx: &Context, argv: Vec<OsString>) -> ExitCode {
        let mut args = Args::new(argv);
        let command = args.next_string();

        match command.as_deref() {
            None => help::Help.run(ctx, args),
            Some("help") | Some("-h") | Some("--help") => help::Help.run(ctx, args),
            Some("version") | Some("-V") | Some("--version") => version::Version.run(ctx, args),
            Some("init") => init::Init.run(ctx, args),
            Some("status") => status::Status.run(ctx, args),
            Some("reload") => reload::Reload.run(ctx, args),
            Some("ipc") => ipc::Ipc.run(ctx, args),
            Some("process") | Some("ps") => process::Process.run(ctx, args),
            Some("settings") => panel::Panel::new("settings").run(ctx, args),
            Some("launcher") => panel::Panel::new("launcher").run(ctx, args),
            Some("recorder") => panel::Panel::new("recorder").run(ctx, args),
            Some("wallpaper") => wallpaper::Wallpaper.run(ctx, args),
            Some("wallify") => {
                wallpaper::Wallpaper.run(ctx, Args::new(vec![OsString::from("select")]))
            }
            Some("clipboard") | Some("clip") => clipboard::Clipboard.run(ctx, args),
            Some("emoji") => emoji::Emoji.run(ctx, args),
            Some("media") | Some("rhythm") => media::Media.run(ctx, args),
            Some("workspace") | Some("tabby") => workspace::Workspace.run(ctx, args),
            Some("powermenu") | Some("power") => panel::Panel::new("powerMenu").run(ctx, args),
            Some("osd") => panel::Panel::new("osd").run(ctx, args),
            Some(other) => {
                log::err(&format!("unknown command `{other}`"));
                log::hint("run `shell help`");
                ExitCode::from(2)
            }
        }
    }
}
