use std::process::ExitCode;

use crate::commands::ShellCommand;
use crate::core::args::Args;
use crate::core::context::Context;
use crate::core::process::Proc;
use crate::ui::log;

pub struct Workspace;

impl ShellCommand for Workspace {
    fn run(&self, ctx: &Context, mut args: Args) -> ExitCode {
        match args.next_string().as_deref() {
            Some("switch") | None => switch(ctx),
            Some(other) => {
                log::err(&format!("unknown workspace command `{other}`"));
                log::hint("use switch");
                ExitCode::from(2)
            }
        }
    }
}

fn switch(ctx: &Context) -> ExitCode {
    let rofi_theme = ctx.paths.home.join(".config/rofi/spotlight.rasi");
    let script = format!(
        r#"
clients="$(hyprctl clients -j | jq -r '.[] | select(.workspace.id >= 0) | "\(.workspace.id)|\(.workspace.name)|\(.class)|\(.title)"')"
if [ -z "$clients" ]; then
  exit 0
fi
choice="$(printf '%s\n' "$clients" | awk -F'|' '{{ printf "󰖯  %s  ·  %s  —  %s\n", $2, $3, $4 }}' | rofi -dmenu -i -p 'workspace' -theme '{}' -l 8)"
[ -z "$choice" ] && exit 0
ws="$(printf '%s\n' "$clients" | while IFS='|' read -r id name class title; do
  line="󰖯  $name  ·  $class  —  $title"
  [ "$line" = "$choice" ] && printf '%s' "$id" && break
done)"
[ -n "$ws" ] && hyprctl dispatch workspace "$ws"
"#,
        rofi_theme.display()
    );

    Proc::status("sh", ["-c", &script])
}
