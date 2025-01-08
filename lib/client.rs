use std::net::SocketAddr;

use crate::message::{self, IORequest};
use bytes::Bytes;
use futures_util::SinkExt;
use log::debug;
use tokio::net::TcpStream;
use tokio_util::codec::{Framed, LengthDelimitedCodec};

use crate::types::{ClientID, RequestNumber};

pub struct Client {
  pub client_id: ClientID,
  pub request_number: RequestNumber,
}

impl Client {
  pub async fn start<F>(s: SocketAddr, f: F)
  where
    F: Fn(&Self) -> Option<message::ClientRequest>,
  {
    let client = Client {
      client_id: 0,
      request_number: 0,
    };
    let connection = TcpStream::connect(s).await.expect("failed to connect");
    let mut framed = Framed::new(connection, LengthDelimitedCodec::new());

    loop {
      match f(&client) {
        None => break,
        Some(request) => {
          let serialized = bincode::serialize(&IORequest::Client(request)).unwrap();
          framed.send(Bytes::from(serialized)).await.unwrap(); // Send the response
          debug!("Sent");

          // let frame = framed.next().await.unwrap().unwrap();
          // let resp: Reply = bincode::deserialize(&frame).unwrap();

          // match resp.result {
          //     crate::operation::OpResult::JoinResult(Ok(id)) => {
          //         client.client_id = id;
          //         client.request_number += 1;
          //     }
          //     crate::operation::OpResult::AddResult(_) => todo!(),
          //     crate::operation::OpResult::UpdateResult(_) => todo!(),
          //     crate::operation::OpResult::RemoveResult(_) => todo!(),
          //     crate::operation::OpResult::Outdated => todo!(),
          //     _ => todo!(),
          // Response::JoinResult(Ok(client_id)) => {
          //     state.client_id = client_id;
          //     state.request_number += 1;
          // }
          // Response::AddResult(Ok(_)) => {}
          // Response::Outdated => {}
          // _ => panic!("TODO: Handle other response cases"),
        }
      }
    }

    // while let Some(com) = f(&client) {}
  }
}
