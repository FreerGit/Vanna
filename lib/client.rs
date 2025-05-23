use std::{
  io::Read,
  net::{SocketAddr, TcpStream},
};

use crate::{
  message::{self, IOMessage},
  network,
};
use log::debug;

use crate::types::{ClientID, RequestID};

pub struct Client {
  pub client_id: ClientID,
  pub request_number: RequestID,
}

impl Client {
  pub async fn start<F>(s: SocketAddr, f: F)
  where
    F: Fn(&Self) -> Option<message::ClientRequest>,
  {
    let client = Client {
      // TODO: This should be generated from a seed for testing.
      client_id: uuid::Uuid::new_v4().as_u128(),
      request_number: 0,
    };
    let mut connection = TcpStream::connect(s).unwrap();

    loop {
      match f(&client) {
        None => break,
        Some(request) => {
          network::write_message(&mut connection, &IOMessage::Client(request)).unwrap();
          debug!("Sent");

          // let frame = framed.next().await.unwrap().unwrap();
          // let resp: Reply = bincode::deserialize(&frame).unwrap();
          // connection.
          // match network::read_message(&mut connection).unwrap() {
          //   IOMessage::Client(client_request) => debug!("{:?}", client_request),
          //   IOMessage::Replica(_) => todo!(),
          //   IOMessage::Reply(reply) => debug!("{:?}", reply),
          // Some(Ok(frame)) => {
          //   debug!("Received frame: {:?}", frame);
          //   match bincode::deserialize::<Reply>(&frame) {
          //     Ok(resp) => {
          //       debug!("{:?}", resp);
          //     }
          //     Err(e) => {
          //       warn!("Failed to deserialize frame: {:?}", e);
          //       todo!()
          //     }
          //   }
          // }
          // None => {
          //   warn!("Connection closed by server");
          //   todo!()
          // }
          // Some(Err(e)) => {
          //   warn!("Error receiving frame: {:?}", e);
          //   todo!()
          // }
          // }
          // debug!("{:?}", resp);
        }
      }
    }
  }
}
