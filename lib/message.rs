use std::{fmt::Debug, net::SocketAddr};

use quickcheck::{Arbitrary, Gen};
use serde::{Deserialize, Serialize};

use crate::{
    operation::{OpResult, Operation},
    types::{ClientID, CommitID, OpNumber, ReplicaID, RequestNumber, ViewNumber},
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
pub struct Prepare {
    pub view_number: ViewNumber,
    pub op: Operation,
    pub op_number: OpNumber,
    pub commit_number: CommitID,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct PrepareOk {
    pub view_number: ViewNumber,
    pub op_number: OpNumber,
    pub replica_number: ReplicaID,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum ReplicaMessage {
    Prepare(Prepare),
    PrepareOk(PrepareOk),
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum IORequest {
    Client(ClientRequest),
    Replica(ReplicaMessage),
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum IOResponse {
    Client(Reply),
    Replica((SocketAddr, ReplicaMessage)),
}
