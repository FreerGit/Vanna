use bytes::Bytes;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum Operation {
    Add { key: Bytes, value: Bytes },
    Update { key: Bytes, value: Bytes },
    Remove { key: Bytes },
    Join,
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum OpResult {
    AddResult(Result<(), ()>),    // TODO: error type
    UpdateResult(Result<(), ()>), // TODO: error type
    RemoveResult(Result<(), ()>), // TODO: error type
    JoinResult(Result<u32, ()>),  // TODO: error type
    Outdated,
}
