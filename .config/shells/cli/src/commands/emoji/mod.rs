use std::ffi::OsString;
use std::process::ExitCode;

use crate::commands::panel::Panel;
use crate::commands::ShellCommand;
use crate::core::args::Args;
use crate::core::context::Context;
use crate::core::process::Proc;
use crate::ui::log;

pub struct Emoji;

impl ShellCommand for Emoji {
    fn run(&self, ctx: &Context, mut args: Args) -> ExitCode {
        match args.next_string().as_deref() {
            Some(action @ ("toggle" | "open" | "close")) => {
                Panel::new("emojiPicker").run(ctx, Args::new(vec![OsString::from(action)]))
            }
            Some("pick") | None => pick(),
            Some(other) => {
                log::err(&format!("unknown emoji command `{other}`"));
                log::hint("use pick, toggle, open, close");
                ExitCode::from(2)
            }
        }
    }
}

fn pick() -> ExitCode {
    let script = r#"rofimoji --action copy --files all --selector-args='-theme-str window {background-color: transparent;} -theme-str mainbox {background-color: transparent;} -theme-str listview {background-color: transparent;} -theme-str element {background-color: transparent;} -theme-str inputbar {background-color: transparent;} -theme-str textbox-prompt-colon {background-color: transparent;}'"#;
    let code = Proc::status("sh", ["-c", script]);
    if code == ExitCode::SUCCESS {
        log::good("emoji copied");
    }
    code
}
