pub struct C;

impl C {
    pub const RESET: &'static str = "\x1b[0m";
    pub const BOLD: &'static str = "\x1b[1m";
    pub const DIM: &'static str = "\x1b[2m";
    pub const RED: &'static str = "\x1b[31m";
    pub const GREEN: &'static str = "\x1b[32m";
    pub const BLUE: &'static str = "\x1b[34m";
    pub const CYAN: &'static str = "\x1b[36m";
}

pub fn good(message: &str) {
    eprintln!("{}{}ok{} {}", C::BOLD, C::GREEN, C::RESET, message);
}

pub fn info(message: &str) {
    eprintln!("{}{}info{} {}", C::BOLD, C::BLUE, C::RESET, message);
}

pub fn hint(message: &str) {
    eprintln!("{}{}hint{} {}", C::BOLD, C::CYAN, C::RESET, message);
}

pub fn err(message: &str) {
    eprintln!("{}{}err{} {}", C::BOLD, C::RED, C::RESET, message);
}

pub fn line(name: &str, value: &str, ok: bool) {
    let mark = if ok {
        format!("{}●{}", C::GREEN, C::RESET)
    } else {
        format!("{}●{}", C::RED, C::RESET)
    };
    println!(
        "{mark} {dim}{name:<12}{reset} {value}",
        dim = C::DIM,
        reset = C::RESET
    );
}
