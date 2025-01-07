use std::fmt::Debug;

use quickcheck::{Arbitrary, Gen};
use serde::{Deserialize, Serialize};

use crate::{
    operation::{OpResult, Operation},
    types::{ClientID, RequestNumber},
};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ClientRequest {
    pub client_id: ClientID,
    pub request_number: RequestNumber,
    pub op: Operation,
}

impl Arbitrary for ClientRequest {
    fn arbitrary(g: &mut Gen) -> Self {
        let client_id = Arbitrary::arbitrary(g);
        let request_number = Arbitrary::arbitrary(g);
        let op: Operation = Arbitrary::arbitrary(g);
        Self {
            client_id,
            request_number,
            op,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Reply {
    pub view_number: u32,
    pub request_number: u32,
    pub result: OpResult,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum ReplicaMessage {
    Prepare {
        view_number: u32,
        message: ClientRequest,
        op_number: u32,
        commit_number: u32,
    },
    PrepareOk {
        view_number: u32,
        op_number: u32,
        replica_number: u32,
    },
}

#[derive(Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum IOMessage {
    ClientRequest(ClientRequest),
    ReplicaMessage(ReplicaMessage),
}

/// Just get the inner struct
impl Debug for IOMessage {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::ClientRequest(arg0) => write!(f, "{:?}", arg0),
            Self::ReplicaMessage(arg0) => write!(f, "{:?}", arg0),
        }
    }
}
