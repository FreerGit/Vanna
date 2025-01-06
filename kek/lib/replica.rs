use std::{collections::VecDeque, sync::Arc};

use crate::{
    configuration::Configuration,
    kvstore::KVStore,
    log::Log,
    message::{Message, ReplicaMessage, Reply},
    operation::OpResult,
    utils::LOGGER,
};
use bytes::Bytes;
use crossbeam::channel::Sender;
use futures_util::{stream::StreamExt, SinkExt};
use tokio::{
    net::{TcpListener, TcpStream},
    sync::Mutex,
};
use tokio_util::codec::{Framed, LengthDelimitedCodec};

#[derive(Clone, Debug)]
pub enum Status {
    Normal,
    ViewChange,
    Recovering,
}

pub type ReplicaID = usize;

#[derive(Clone, Debug)]
pub struct Replica {
    conf: Configuration,
    replica: ReplicaID, // This is the index into conf
    view: u32,          // view number, initially 0
    status: Status,
    op_num: u32, // the most recently recieved request, initially 0
    log: Log,
    commit: u32, // commit number, the most recent committed op_number
    // client_table
    store: KVStore,
    client_tx: VecDeque<Reply>,
    replica_tx: VecDeque<(ReplicaID, ReplicaMessage)>,
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
            client_tx: VecDeque::new(),
            replica_tx: VecDeque::new(),
        }
    }
}
