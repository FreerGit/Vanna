use std::{collections::VecDeque, net::SocketAddr};

use crate::{
    client_table::ClienTable,
    configuration::Configuration,
    kvstore::KVStore,
    log::Log,
    message::{ClientRequest, IOMessage, Prepare, PrepareOk, ReplicaMessage, Reply},
    types::{CommitID, OpNumber, ReplicaID, ViewNumber},
    utils::{do_nothing, LOGGER},
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
    client_tx: VecDeque<Reply>,
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
            client_tx: VecDeque::new(),
            replica_tx: VecDeque::new(),
        }
    }

    pub fn on_message(&mut self, message: IOMessage) {
        let (x, y) = (self.replica, message.clone());
        LOGGER.with(|logger| {
            logger.debug(move || format!("Replica {} <- {:?}", x, y));
        });
        match message {
            IOMessage::ClientRequest(client_request) => self.on_request(client_request),
            IOMessage::ReplicaMessage(replica_message) => match replica_message {
                ReplicaMessage::Prepare(prepare) => self.on_prepare(prepare),
                ReplicaMessage::PrepareOk(_) => todo!(),
            },
        }
    }

    fn on_request(&mut self, req: ClientRequest) -> () {
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
            self.replica_tx
                .push_front((*c, ReplicaMessage::Prepare(msg.clone())));
        }
    }

    fn send_prepare_ok(&mut self, primary: SocketAddr, prepareok: PrepareOk) {
        self.replica_tx
            .push_front((primary, ReplicaMessage::PrepareOk(prepareok)));
    }

    fn is_primary(&self) -> bool {
        self.replica == self.conf.primary_id(self.view)
    }

    fn is_backup(&self) -> bool {
        !self.is_primary()
    }

    pub fn dequeue_client_reply(&mut self) -> Option<Reply> {
        self.client_tx.pop_front()
    }

    pub fn dequeue_replica_messages(
        &mut self,
    ) -> impl Iterator<Item = (SocketAddr, ReplicaMessage)> + '_ {
        self.replica_tx.drain(..)
    }
}
