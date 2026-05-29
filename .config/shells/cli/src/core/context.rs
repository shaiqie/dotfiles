use super::paths::ShellPaths;

#[derive(Debug, Clone)]
pub struct Context {
    pub paths: ShellPaths,
}

impl Context {
    pub fn new() -> Self {
        Self {
            paths: ShellPaths::new(),
        }
    }
}
