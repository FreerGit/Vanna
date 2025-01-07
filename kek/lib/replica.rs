use std::{cell::RefCell, collections::VecDeque, net::SocketAddr};

use crate::{
    configuration::Configuration,
    kvstore::KVStore,
    log::Log,
    message::{ClientRequest, IOMessage, ReplicaMessage, Reply},
    types::{CommitID, OpNumber, ReplicaID, ViewNumber},
    utils::LOGGER,
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
    op_num: OpNumber, // the most recently recieved request, initially 0
    log: Log,
    commit: CommitID, // commit number, the most recent committed op_number
    // client_table
    store: KVStore,
    client_tx: RefCell<VecDeque<Reply>>,
    replica_tx: RefCell<VecDeque<(SocketAddr, ReplicaMessage)>>,
}

impl Replica {
    pub fn new(conf: Configuration, replica: ReplicaID) -> Self {
        Replica {
            conf,
            replica,
            view: 0,
            status: Status::Normal,
            op_num: 0,
            commit: 0,
            log: Log::new(),
            store: KVStore::new(),
            client_tx: RefCell::new(VecDeque::new()),
            replica_tx: RefCell::new(VecDeque::new()),
        }
    }

    pub fn on_message(&self, message: IOMessage) {
        let (x, y) = (self.replica.clone(), message.clone());
        LOGGER.debug(move || format!("Replica {} <- {:?}", x, y));

        match message {
            IOMessage::ClientRequest(client_request) => self.on_request(client_request),
            IOMessage::ReplicaMessage(replica_message) => match replica_message {
                crate::message::ReplicaMessage::Prepare {
                    view_number,
                    message,
                    op_number,
                    commit_number,
                } => todo!(),
                crate::message::ReplicaMessage::PrepareOk {
                    view_number,
                    op_number,
                    replica_number,
                } => todo!(),
            },
        }
    }

    fn on_request(&self, req: ClientRequest) -> () {
        assert!(self.is_primary());
        assert_eq!(self.status, Status::Normal);
        // match req.request_number {

        // }
    }

    fn is_primary(&self) -> bool {
        self.replica == self.conf.primary_id(self.view)
    }

    pub async fn dequeue_client_reply(&self) -> Option<Reply> {
        self.client_tx.borrow_mut().pop_front()
    }

    pub async fn dequeue_replica_message(&self) -> Option<(SocketAddr, ReplicaMessage)> {
        self.replica_tx.borrow_mut().pop_front()
    }
}
