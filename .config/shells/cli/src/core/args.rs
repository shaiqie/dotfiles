use std::ffi::OsString;

#[derive(Debug, Default)]
pub struct Args {
    values: Vec<OsString>,
}

impl Args {
    pub fn new(values: Vec<OsString>) -> Self {
        Self { values }
    }

    pub fn next_string(&mut self) -> Option<String> {
        if self.values.is_empty() {
            return None;
        }
        Some(self.values.remove(0).to_string_lossy().to_string())
    }

    pub fn rest(self) -> Vec<OsString> {
        self.values
    }
}
