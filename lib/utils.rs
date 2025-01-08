use ring_log::Logger;

use std::sync::{LazyLock, Mutex};

pub static LOGGER: LazyLock<Mutex<Logger>> =
  LazyLock::new(|| Mutex::new(Logger::builder(None).with_time(false)));

/// For explicitness
pub fn do_nothing() {}
