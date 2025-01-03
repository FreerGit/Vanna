use once_cell::sync::Lazy;
use ring_log::Logger;

pub const LOGGER: Lazy<Logger> = Lazy::new(|| Logger::builder(None).with_time(false));
