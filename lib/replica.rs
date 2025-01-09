use std::{collections::VecDeque, net::SocketAddr};

use log::debug;

use crate::{
  client_table::ClienTable,
  configuration::Configuration,
  log::Log,
  message::{ClientRequest, IORequest, Prepare, PrepareOk, ReplicaMessage, Reply},
  operation::OpResult,
  types::{CommitID, ReplicaID, ViewNumber},
};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Status {
  Normal,
  ViewChange,
  Recovering,
}

#[derive(Clone, Debug)]
pub struct Replica {
  conf: Configuration,
  replica: ReplicaID, // This is the index into conf
  view: ViewNumber,   // view number, initially 0
  status: Status,
  log: Log,
  commit: CommitID, // commit number, the most recent committed op_number
  client_table: ClienTable,
  // store: KVStore,
  client_tx: VecDeque<Reply>, // TODO: per client
  replica_tx: VecDeque<(SocketAddr, ReplicaMessage)>,
}

impl Replica {
  pub fn new(conf: Configuration, replica: ReplicaID) -> Self {
    Replica {
      conf,
      replica,
      view: 0,
      status: Status::Normal,
      commit: 0,
      log: Log::default(),
      client_table: ClienTable::default(),
      // store: KVStore::default(),
      client_tx: VecDeque::default(),
      replica_tx: VecDeque::default(),
    }
  }

  pub fn on_message(&mut self, message: IORequest) {
    debug!("Replica {} <- {:?}", self.replica, message);

    match message {
      IORequest::Client(client_request) => self.on_request(client_request),
      IORequest::Replica(replica_message) => match replica_message {
        ReplicaMessage::Prepare(prepare) => self.on_prepare(prepare),
        ReplicaMessage::PrepareOk(ok) => self.on_prepare_ok(ok),
      },
    }
  }

  fn on_request(&mut self, req: ClientRequest) {
    assert!(self.is_primary());
    assert_eq!(self.status, Status::Normal);
    let last_op_num = self.log.append(self.view, req.op.clone());

    self.broadcast_prepare(Prepare {
      view_number: self.view,
      op: req.op,
      op_number: last_op_num,
      commit_number: self.commit,
    });
  }

  fn on_prepare(&mut self, prepare: Prepare) {
    assert!(self.is_backup());

    self.log.append(self.view, prepare.op);
    self.commit_ops(prepare.commit_number);

    let primary = self.conf.primary_id(self.view);

    self.replica_tx.push_back((
      self.conf.find_addr(primary),
      ReplicaMessage::PrepareOk(PrepareOk {
        view_number: self.view,
        op_number: prepare.op_number,
        replica_number: self.replica,
      }),
    ));
  }

  fn on_prepare_ok(&mut self, ok: PrepareOk) {
    assert!(self.is_primary());
    // TODO - state update

    let r = Reply {
      view_number: ok.view_number,
      request_number: 0, // TODO
      result: OpResult::Outdated,
    };

    self.client_tx.push_back(r);
  }

  fn commit_ops(&mut self, commit: CommitID) {
    while self.commit < commit {
      self.commit += 1;
      let op = &self.log.entries[self.commit];
      match op {
        crate::operation::Operation::Join => {
          self.client_table.add_client();
        }
        _ => todo!(), // crate::operation::Operation::Add { key, value } => todo!(),
                      // crate::operation::Operation::Update { key, value } => todo!(),
                      // crate::operation::Operation::Remove { key } => todo!(),
      }
    }
  }

  fn broadcast_prepare(&mut self, msg: Prepare) {
    for (i, c) in self.conf.replicas.iter().enumerate() {
      if self.replica == i {
        continue;
      }
      self
        .replica_tx
        .push_back((*c, ReplicaMessage::Prepare(msg.clone())));
    }
  }

  fn is_primary(&self) -> bool {
    self.replica == self.conf.primary_id(self.view)
  }

  fn is_backup(&self) -> bool {
    !self.is_primary()
  }

  pub fn dequeue_replica_msg(&mut self) -> Option<(SocketAddr, ReplicaMessage)> {
    self.replica_tx.pop_front()
  }

  pub fn dequeue_client_reply(&mut self) -> Option<Reply> {
    self.client_tx.pop_front()
  }
}
