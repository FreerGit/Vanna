use std::net::SocketAddr;

use bytes::Bytes;
use crossbeam::channel::{Receiver, Sender};
use futures_util::{SinkExt, StreamExt};
use log::{debug, warn};
use tokio::net::{TcpListener, TcpStream};
use tokio_util::codec::{Framed, LengthDelimitedCodec};

use crate::message::{IORequest, IOResponse};

async fn handle_connection(s: TcpStream, client_tx: Sender<IORequest>) {
  debug!("in handle");
  let mut framed = Framed::new(s, LengthDelimitedCodec::new());
  loop {
    match framed.next().await {
      None => {
        warn!("Connection closed");
        break;
      }
      Some(frame) => match frame {
        Ok(bytes) => {
          let message: IORequest = bincode::deserialize(&bytes).unwrap();

          client_tx.send(message).unwrap();
        }
        Err(_) => todo!(),
      },
    }
  }
}

pub async fn start_io_layer(
  addr: SocketAddr,
  client_tx: Sender<IORequest>,
  replica_rx: Receiver<IOResponse>,
) {
  let listener = TcpListener::bind(addr).await.unwrap();

  // start sender
  tokio::spawn(async move {
    debug!("Start sender");
    loop {
      match replica_rx.recv() {
        Err(_) => break,
        Ok(msg) => match msg {
          // TODO make this a function once i figure out reply
          IOResponse::Client(_reply) => todo!(),
          IOResponse::Replica((s, m)) => {
            debug!("got replica msg");
            let connection = TcpStream::connect(s).await.expect("failed to connect");
            let mut framed = Framed::new(connection, LengthDelimitedCodec::new());
            let serialzied = bincode::serialize(&IORequest::Replica(m)).unwrap();
            framed.send(Bytes::from(serialzied)).await.unwrap();
            debug!("Sent");
          }
        },
      }
    }
  });

  loop {
    if let Ok((socket, _)) = listener.accept().await {
      debug!("in accept");
      let client_tx = client_tx.clone();
      // let replica_rx = replica_rx.clone();

      tokio::spawn(async move { handle_connection(socket, client_tx).await });
      debug!("spawned");
    }
  }
}
