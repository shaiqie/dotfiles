use std::ffi::{OsStr, OsString};
use std::io::Write;
use std::process::{Command, ExitCode, Stdio};

use crate::ui::log;

pub struct Proc;

impl Proc {
    pub fn status<I, S>(program: &str, args: I) -> ExitCode
    where
        I: IntoIterator<Item = S>,
        S: AsRef<OsStr>,
    {
        match Command::new(program)
            .args(args)
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit())
            .status()
        {
            Ok(status) if status.success() => ExitCode::SUCCESS,
            Ok(status) => ExitCode::from(status.code().unwrap_or(1) as u8),
            Err(error) => {
                log::err(&format!("cannot run {program}: {error}"));
                ExitCode::from(127)
            }
        }
    }

    pub fn quiet_status<I, S>(program: &str, args: I) -> bool
    where
        I: IntoIterator<Item = S>,
        S: AsRef<OsStr>,
    {
        Command::new(program)
            .args(args)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .map(|s| s.success())
            .unwrap_or(false)
    }

    pub fn output<I, S>(program: &str, args: I) -> Option<String>
    where
        I: IntoIterator<Item = S>,
        S: AsRef<OsStr>,
    {
        Command::new(program)
            .args(args)
            .output()
            .ok()
            .filter(|o| o.status.success())
            .map(|o| String::from_utf8_lossy(&o.stdout).to_string())
    }

    pub fn spawn<I, S>(program: &str, args: I) -> bool
    where
        I: IntoIterator<Item = S>,
        S: AsRef<OsStr>,
    {
        Command::new(program)
            .args(args)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .is_ok()
    }

    pub fn pipe(program: &str, args: &[&str], input: &[u8]) -> Option<String> {
        Self::pipe_bytes(program, args, input)
            .map(|bytes| String::from_utf8_lossy(&bytes).to_string())
    }

    pub fn pipe_bytes(program: &str, args: &[&str], input: &[u8]) -> Option<Vec<u8>> {
        let mut child = Command::new(program)
            .args(args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .ok()?;

        if let Some(stdin) = child.stdin.as_mut() {
            stdin.write_all(input).ok()?;
        }

        let output = child.wait_with_output().ok()?;
        if output.status.success() {
            Some(output.stdout)
        } else {
            None
        }
    }

    pub fn write_stdin(program: &str, args: &[&str], input: &[u8]) -> bool {
        let mut child = match Command::new(program)
            .args(args)
            .stdin(Stdio::piped())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
        {
            Ok(child) => child,
            Err(_) => return false,
        };

        if let Some(stdin) = child.stdin.as_mut() {
            if stdin.write_all(input).is_err() {
                return false;
            }
        }

        child.wait().map(|status| status.success()).unwrap_or(false)
    }

    pub fn tool_exists(name: &str) -> bool {
        Self::quiet_status("sh", ["-c", &format!("command -v {name} >/dev/null 2>&1")])
    }

    pub fn tool_version(name: &str) -> String {
        if !Self::tool_exists(name) {
            return "missing".to_string();
        }
        Self::output(name, ["--version"])
            .and_then(|text| text.lines().next().map(str::trim).map(str::to_string))
            .filter(|line| !line.is_empty())
            .unwrap_or_else(|| "installed".to_string())
    }

    pub fn os_args(args: Vec<OsString>) -> Vec<OsString> {
        args
    }
}
