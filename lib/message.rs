use std::fmt::Debug;

use quickcheck::{Arbitrary, Gen};
use serde::{Deserialize, Serialize};

use crate::{
  operation::{OpResult, Operation},
  types::{ClientID, CommitID, OpNumber, ReplicaID, RequestID, ViewNumber},
};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ClientRequest {
  pub client_id: ClientID,
  pub request_number: RequestID,
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
  pub view_number: ViewNumber,
  pub request_number: RequestID,
  pub result: OpResult,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Prepare {
  pub view_number: ViewNumber,
  pub request: ClientRequest,
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
pub enum IOMessage {
  Reply(Reply),
  Client(ClientRequest),
  Replica(ReplicaMessage),
}
