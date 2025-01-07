use once_cell::sync::Lazy;
use ring_log::Logger;
use std::cell::RefCell;

thread_local! {
    pub static LOGGER: Logger = Logger::builder(None).with_time(false);
}
/// For explicitness
pub fn do_nothing() -> () {}
