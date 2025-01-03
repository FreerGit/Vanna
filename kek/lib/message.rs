use serde::{Deserialize, Serialize};

use crate::operation::{OpResult, Operation};

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Request {
    pub client_id: u32,
    pub request_number: u32,
    pub op: Operation,
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Reply {
    pub view_number: u32,
    pub request_number: u32,
    pub result: OpResult,
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum Replica {
    Prepare {
        view_number: u32,
        message: Request,
        op_number: u32,
        commit_number: u32,
    },
    PrepareOk {
        view_number: u32,
        op_number: u32,
        replica_number: u32,
    },
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum Message {
    ClientRequest(Request),
    ReplicaMessage(Replica),
}
