use std::{cell::RefCell, net::SocketAddr, rc::Rc};

use bytes::Bytes;
use futures_util::{SinkExt, StreamExt};
use log::debug;
use tokio::{
  net::{TcpListener, TcpStream},
  task::LocalSet,
};
use tokio_util::codec::{Framed, LengthDelimitedCodec};

use crate::{message::IORequest, replica::Replica};

async fn handle_connection(replica: Rc<RefCell<Replica>>, s: TcpStream) {
  let mut framed = Framed::new(s, LengthDelimitedCodec::new());
  loop {
    match framed.next().await {
      None => break,
      Some(Err(_)) => todo!(),
      Some(Ok(bytes)) => {
        let message: IORequest = bincode::deserialize(&bytes).unwrap();
        let mut replica = replica.borrow_mut();
        replica.on_message(message);

        // Respond to client
        while let Some(reply) = replica.dequeue_client_reply() {
          let serialized = bincode::serialize(&reply).unwrap();
          framed.send(Bytes::from(serialized)).await.unwrap();
          debug!("Sent to client");
        }

        // Send to replicas
        while let Some((addr, msg)) = replica.dequeue_replica_msg() {
          tokio::task::spawn_local(async move {
            let connection = TcpStream::connect(addr).await.expect("failed to connect");
            let mut framed = Framed::new(connection, LengthDelimitedCodec::new());
            let serialized = bincode::serialize(&IORequest::Replica(msg)).unwrap();
            framed.send(Bytes::from(serialized)).await.unwrap();
            debug!("Sent to replica");
          });
        }
      }
    }
  }
}

pub async fn start_io_layer(replica: Replica, addr: SocketAddr) {
  let listener = TcpListener::bind(addr).await.unwrap();
  let replica_rc = Rc::new(RefCell::new(replica.clone()));

  let local_set = LocalSet::new();
  local_set
    .run_until(async move {
      loop {
        if let Ok((socket, _)) = listener.accept().await {
          let c = Rc::clone(&replica_rc);
          tokio::task::spawn_local(async move {
            handle_connection(c, socket).await;
          });
        }
      }
    })
    .await;
}
