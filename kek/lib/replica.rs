use crate::{
    configuration::Configuration,
    kvstore::KVStore,
    message::{Message, Reply},
    operation::OpResult,
    utils::LOGGER,
};
use bytes::Bytes;
use futures_util::{stream::StreamExt, SinkExt};
use tokio::net::{TcpListener, TcpStream};
use tokio_util::codec::{Framed, LengthDelimitedCodec};

// configuration : Configuration.t
//         (* TODO: make sure that the invariant holds for the index when updating config. *)
//     ; replica_number : int (* This is the index into its IP in configuration *)
//     ; view_number : int (* Initially 0 *)
//     ; status : Status.t
//     ; op_number : int (* Initially 0, the most recently recieved request *)
//     ; log : Log.t (* Ordered list of operations *)
//     ; commit_number : int (* The most recent commited op_number *)
//     ; client_table : ClientTable.t
//     ; store : KVStore.t

#[derive(Clone, Debug)]
pub enum Status {
    Normal,
    ViewChange,
    Recovering,
}

#[derive(Clone, Debug)]
pub struct Replica {
    conf: Configuration,
    replica: usize, // This is the index into conf
    view: u32,      // view number, initially 0
    status: Status,
    op_num: u32, // the most recently recieved request, initially 0
    // log
    commit: u32, // commit number, the most recent committed op_number
    // client_table
    store: KVStore,
}

impl Replica {
    async fn handle_connection(&mut self, connection: TcpStream) {
        let mut framed = Framed::new(connection, LengthDelimitedCodec::new());
        loop {
            let frame = framed.next().await.unwrap();

            match frame {
                Ok(bytes) => {
                    // Deserialize the bytes into a Message
                    let message: Message = bincode::deserialize(&bytes).unwrap();
                    let pp = message.clone();
                    LOGGER.info(move || format!("{:?}", pp));

                    let result = match message {
                        Message::ClientRequest(request) => match request.op {
                            crate::operation::Operation::Add { key, value } => todo!(),
                            crate::operation::Operation::Update { key, value } => todo!(),
                            crate::operation::Operation::Remove { key } => todo!(),
                            crate::operation::Operation::Join => OpResult::JoinResult(Ok(1)),
                        },
                        Message::ReplicaMessage(replica) => todo!(),
                    };
                    let reply = Reply {
                        view_number: 0,
                        request_number: 0,
                        result,
                    };
                    let serialized = bincode::serialize(&reply).unwrap();

                    // Send the response (write the length-prefixed frame)
                    framed.send(Bytes::from(serialized)).await.unwrap();
                }
                Err(_) => todo!(),
            }
        }
    }

    pub async fn start(conf: Configuration, replica: usize) {
        let addr = conf.find_addr(replica);
        let c = addr.clone();

        LOGGER.info(move || format!("{} {:?}", "Replica started on", c));
        let listener = TcpListener::bind(addr).await.unwrap();

        let r = Replica {
            conf,
            replica,
            view: 0,
            status: Status::Normal,
            op_num: 0,
            commit: 0,
            store: KVStore::new(),
        };

        loop {
            let (socket, _) = listener.accept().await.unwrap();
            let mut state = r.clone();
            tokio::spawn(async move {
                state.handle_connection(socket).await;
            });
        }
    }
}
