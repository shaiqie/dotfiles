use std::process::ExitCode;

use crate::commands::ShellCommand;
use crate::core::args::Args;
use crate::core::context::Context;
use crate::core::process::Proc;
use crate::ui::log;
use crate::ui::log::C;

pub struct Process;

#[derive(Debug)]
struct QuickProcess {
    pid: String,
    age: String,
    state: String,
    args: String,
}

impl ShellCommand for Process {
    fn run(&self, _ctx: &Context, mut args: Args) -> ExitCode {
        match args.next_string().as_deref() {
            Some("list") | None => list(),
            Some("stop") | Some("kill") => match args.next_string() {
                Some(pid) => stop(&pid),
                None => {
                    log::err("usage: shell process stop <pid>");
                    ExitCode::from(2)
                }
            },
            Some(other) => {
                log::err(&format!("unknown process command `{other}`"));
                log::hint("use `shell process` or `shell process stop <pid>`");
                ExitCode::from(2)
            }
        }
    }
}

fn list() -> ExitCode {
    let processes = quickshell_processes();
    if processes.is_empty() {
        log::hint("no quickshell process running");
        return ExitCode::SUCCESS;
    }

    println!(
        "{bold}{blue}Quickshell processes{reset}\n",
        bold = C::BOLD,
        blue = C::BLUE,
        reset = C::RESET
    );
    println!(
        "{dim}{:<8} {:<10} {:<7} {}{reset}",
        "PID",
        "AGE",
        "STATE",
        "COMMAND",
        dim = C::DIM,
        reset = C::RESET
    );

    for process in processes {
        println!(
            "{green}●{reset} {bold}{:<6}{reset} {cyan}{:<10}{reset} {dim}{:<7}{reset} {}",
            process.pid,
            process.age,
            process.state,
            trim_args(&process.args),
            green = C::GREEN,
            cyan = C::CYAN,
            bold = C::BOLD,
            dim = C::DIM,
            reset = C::RESET
        );
    }

    ExitCode::SUCCESS
}

fn stop(pid: &str) -> ExitCode {
    if !pid.chars().all(|ch| ch.is_ascii_digit()) || pid == "0" {
        log::err("pid must be a number");
        return ExitCode::from(2);
    }

    let args = Proc::output("ps", ["-p", pid, "-o", "args="]).unwrap_or_default();
    if !args.contains("quickshell") {
        log::err(&format!("pid {pid} is not a quickshell process"));
        return ExitCode::from(1);
    }

    let code = Proc::status("kill", [pid]);
    if code == ExitCode::SUCCESS {
        log::good(&format!("stopped quickshell pid {pid}"));
    }
    code
}

fn quickshell_processes() -> Vec<QuickProcess> {
    let Some(output) = Proc::output("ps", ["-eo", "pid=,etime=,stat=,args="]) else {
        return Vec::new();
    };

    let mut processes = Vec::new();
    for line in output.lines() {
        let mut parts = line.trim().splitn(4, char::is_whitespace);
        let Some(pid) = parts.next() else {
            continue;
        };
        let Some(age) = parts.next() else {
            continue;
        };
        let Some(state) = parts.next() else {
            continue;
        };
        let Some(args) = parts.next() else {
            continue;
        };

        if args.contains("quickshell") && !args.contains("grep") {
            processes.push(QuickProcess {
                pid: pid.to_string(),
                age: age.to_string(),
                state: state.to_string(),
                args: args.trim().to_string(),
            });
        }
    }

    processes
}

fn trim_args(args: &str) -> String {
    const MAX: usize = 96;
    if args.chars().count() <= MAX {
        return args.to_string();
    }

    let mut short = args.chars().take(MAX - 1).collect::<String>();
    short.push('…');
    short
}
