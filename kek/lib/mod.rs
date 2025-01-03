#[cfg(test)]
extern crate quickcheck;
#[cfg(test)]
#[macro_use(quickcheck)]
extern crate quickcheck_macros;

pub mod client;
pub mod configuration;
pub mod kvstore;
pub mod message;
pub mod operation;
pub mod replica;
pub mod utils;
