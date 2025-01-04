use quickcheck::{Arbitrary, Gen};
use serde::{Deserialize, Serialize};

use crate::operation::{OpResult, Operation};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Request {
    pub client_id: u32,
    pub request_number: u32,
    pub op: Operation,
}

impl Arbitrary for Request {
    fn arbitrary(g: &mut Gen) -> Self {
        let client_id: u32 = Arbitrary::arbitrary(g);
        let request_number: u32 = Arbitrary::arbitrary(g);
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

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum Message {
    ClientRequest(Request),
    ReplicaMessage(Replica),
}
