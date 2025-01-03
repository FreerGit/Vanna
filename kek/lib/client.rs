use std::{
    io::Write,
    net::{SocketAddr, TcpStream},
};

use crate::message::{Message, Reply};

pub struct Client {
    pub client_id: u32,
    pub request_number: u32,
}

impl Client {
    pub fn start<F>(s: SocketAddr, f: F) -> ()
    where
        F: Fn(&Self) -> Option<Message>,
    {
        let mut client = Client {
            client_id: 0,
            request_number: 0,
        };
        let mut connection = TcpStream::connect(s).expect("failed to connect");

        loop {
            match f(&client) {
                None => break,
                Some(request) => {
                    bincode::serialize_into(&mut connection, &request).unwrap();
                    // connection.write_all(&bytes).expect("Failed to send bytes");
                    // connection
                    let resp = bincode::deserialize_from::<_, Reply>(&mut connection).unwrap();

                    match resp.result {
                        crate::operation::OpResult::JoinResult(Ok(id)) => {
                            client.client_id = id;
                            client.request_number += 1;
                        }
                        crate::operation::OpResult::AddResult(_) => todo!(),
                        crate::operation::OpResult::UpdateResult(_) => todo!(),
                        crate::operation::OpResult::RemoveResult(_) => todo!(),
                        crate::operation::OpResult::Outdated => todo!(),
                        _ => todo!(),
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
        }

        while let Some(com) = f(&client) {}
    }
}
