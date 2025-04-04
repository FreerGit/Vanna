use std::{
  collections::VecDeque,
  net::{SocketAddr, TcpStream},
};

use log::debug;

use crate::{
  client_table::ClienTable,
  configuration::Configuration,
  log::Log,
  message::{ClientRequest, IOMessage, Prepare, PrepareOk, ReplicaMessage, Reply},
  network::{write_message, ConnectionTable},
  operation::OpResult,
  types::{CommitID, ConnectionID, ReplicaID, ViewNumber},
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
  // reached_consensus: HashMap<OpNumber, HashSet<ReplicaID, usize>>,
  // store: KVStore,
  client_sessions: ConnectionTable,
  replica_tx: VecDeque<(ReplicaID, ReplicaMessage)>,
}

impl Replica {
  pub fn new(conf: Configuration, replica: ReplicaID, client_sessions: ConnectionTable) -> Self {
    Replica {
      conf,
      replica,
      view: 0,
      status: Status::Normal,
      commit: 0,
      log: Log::default(),
      client_table: ClienTable::default(),
      // reached_consensus: HashMap::default(),
      // store: KVStore::default(),
      client_sessions,
      replica_tx: VecDeque::default(),
    }
  }

  pub fn on_client_request(&mut self, req: ClientRequest, conn_id: ConnectionID) {
    assert!(self.is_primary());
    assert_eq!(self.status, Status::Normal);

    self.client_sessions.insert(req.client_id, conn_id);

    let last_op_num = self.log.append(self.view, req.clone());
    self.client_table.insert(req.client_id, req.request_number);

    self.broadcast_prepare(Prepare {
      view_number: self.view,
      request: req,
      op_number: last_op_num,
      commit_number: self.commit,
    });
  }

  pub fn on_replica_message(&mut self, msg: ReplicaMessage) {
    match msg {
      ReplicaMessage::Prepare(prepare) => todo!(),
      ReplicaMessage::PrepareOk(ok) => todo!(),
    }
  }

  // fn on_prepare(&mut self, prepare: Prepare) {
  //   assert!(self.is_backup());

  //   self.log.append(self.view, prepare.request);
  //   self.commit_ops(prepare.commit_number);

  //   let primary = self.conf.primary_id(self.view);

  //   self.replica_tx.push_back((
  //     self.conf.find_addr(primary),
  //     ReplicaMessage::PrepareOk(PrepareOk {
  //       view_number: self.view,
  //       op_number: prepare.op_number,
  //       replica_number: self.replica,
  //     }),
  //   ));
  // }

  // fn on_prepare_ok(&mut self, ok: PrepareOk) {
  //   assert!(self.is_primary());
  //   // TODO - state update

  //   let r = Reply {
  //     view_number: ok.view_number,
  //     request_number: 0, // TODO
  //     result: OpResult::Outdated,
  //   };

  //   // TODO qourum
  //   // see that majority is reached through PrepareOk

  //   // TODO commit
  //   let req = &self.log.entries[self.commit];
  //   debug!("PrepareOk {:?}", req);

  //   // TODO, now time to "send" reply

  //   // self.client_tx.push_back(r);
  //   // let mut binding = self.client_sessions.lock().unwrap();
  //   // let x = binding.get_mut(&req.client_id).unwrap();

  //   write_message(x, &IOMessage::Reply(r)).unwrap();
  // }

  fn commit_ops(&mut self, commit: CommitID) {
    while self.commit < commit {
      self.commit += 1;
      let req = &self.log.entries[self.commit];
      match req.op {
        crate::operation::Operation::Join => {
          // self.client_table.add_client();
        }
        _ => todo!(), // crate::operation::Operation::Add { key, value } => todo!(),
                      // crate::operation::Operation::Update { key, value } => todo!(),
                      // crate::operation::Operation::Remove { key } => todo!(),
      }
    }
  }

  fn broadcast_prepare(&mut self, msg: Prepare) {
    for (i, _) in self.conf.replicas.iter().enumerate() {
      if self.replica == i {
        continue;
      }
      self
        .replica_tx
        .push_back((i, ReplicaMessage::Prepare(msg.clone())));
    }
  }

  fn is_primary(&self) -> bool {
    self.replica == self.conf.primary_id(self.view)
  }

  fn is_backup(&self) -> bool {
    !self.is_primary()
  }

  pub fn dequeue_replica_msg(&mut self) -> Option<(ReplicaID, ReplicaMessage)> {
    self.replica_tx.pop_back()
  }
}
