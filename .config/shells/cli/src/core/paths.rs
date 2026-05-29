use std::env;
use std::path::PathBuf;

#[derive(Debug, Clone)]
pub struct ShellPaths {
    pub home: PathBuf,
    pub config_dir: PathBuf,
    pub cache_dir: PathBuf,
    pub quickshell_cache_dir: PathBuf,
    pub wallpaper_dir: PathBuf,
}

impl ShellPaths {
    pub fn new() -> Self {
        let home = env::var_os("HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("."));
        let config_dir = env::var_os("SHELLS_CONFIG_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(".config/shells"));
        let cache_dir = env::var_os("SHELLS_CACHE_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(".cache/shells"));
        let quickshell_cache_dir = home.join(".cache/quickshell");
        let wallpaper_dir = env::var_os("SHELLS_WALLPAPER_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(".config/hypr/wallpapers"));

        Self {
            home,
            config_dir,
            cache_dir,
            quickshell_cache_dir,
            wallpaper_dir,
        }
    }

    pub fn shell_qml(&self) -> PathBuf {
        self.config_dir.join("shell.qml")
    }
}
