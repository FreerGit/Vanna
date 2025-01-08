use std::{net::SocketAddr, thread};

use crossbeam::channel::{Receiver, Sender};
use log::debug;

use crate::{
  client_table::ClienTable,
  configuration::Configuration,
  log::Log,
  message::{ClientRequest, IORequest, IOResponse, Prepare, PrepareOk, ReplicaMessage},
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
  rx: Receiver<IORequest>,
  tx: Sender<IOResponse>,
}

impl Replica {
  pub fn new(
    conf: Configuration,
    replica: ReplicaID,
    rx: Receiver<IORequest>,
    tx: Sender<IOResponse>,
  ) -> Self {
    Replica {
      conf,
      replica,
      view: 0,
      status: Status::Normal,
      commit: 0,
      log: Log::default(),
      client_table: ClienTable::default(),
      // store: KVStore::default(),
      rx,
      tx,
    }
  }

  /// Starts
  pub fn start(self) {
    thread::spawn(move || {
      let mut replica = self;
      loop {
        match replica.rx.recv() {
          Ok(msg) => replica.on_message(msg),
          Err(_) => todo!(),
        }
      }
    });
  }

  pub fn on_message(&mut self, message: IORequest) {
    let (x, y) = (self.replica, message.clone());
    debug!("Replica {} <- {:?}", x, y);

    match message {
      IORequest::Client(client_request) => self.on_request(client_request),
      IORequest::Replica(replica_message) => match replica_message {
        ReplicaMessage::Prepare(prepare) => self.on_prepare(prepare),
        ReplicaMessage::PrepareOk(_) => todo!(),
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
    self.send_prepare_ok(
      self.conf.find_addr(primary),
      PrepareOk {
        view_number: self.view,
        op_number: prepare.op_number,
        replica_number: self.replica,
      },
    )
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
        .tx
        .send(IOResponse::Replica((
          *c,
          ReplicaMessage::Prepare(msg.clone()),
        )))
        .unwrap();
    }
  }

  fn send_prepare_ok(&mut self, primary: SocketAddr, prepareok: PrepareOk) {
    self
      .tx
      .send(IOResponse::Replica((
        primary,
        ReplicaMessage::PrepareOk(prepareok),
      )))
      .unwrap();
  }

  fn is_primary(&self) -> bool {
    self.replica == self.conf.primary_id(self.view)
  }

  fn is_backup(&self) -> bool {
    !self.is_primary()
  }
}
