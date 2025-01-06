use crate::utils::LOGGER;

// pub fn start_replica() {
//     // LOGGER.info(move || format!("Starting replica on {:?}", c));
// }

// let addr = conf.find_addr(replica);
// let c = addr.clone();

// async fn handle_connection(&mut self, connection: TcpStream) {
//     let mut framed = Framed::new(connection, LengthDelimitedCodec::new());
//     loop {
//         let frame = framed.next().await.unwrap();

//         match frame {
//             Ok(bytes) => {
//                 let message: Message = bincode::deserialize(&bytes).unwrap();
//                 let pp = message.clone();
//                 LOGGER.info(move || format!("{:?}", pp));

//                 let result = match message {
//                     Message::ClientRequest(request) => match request.op {
//                         crate::operation::Operation::Add { key, value } => todo!(),
//                         crate::operation::Operation::Update { key, value } => todo!(),
//                         crate::operation::Operation::Remove { key } => todo!(),
//                         crate::operation::Operation::Join => OpResult::JoinResult(Ok(1)),
//                     },
//                     Message::ReplicaMessage(replica) => todo!(),
//                 };
//                 let reply = Reply {
//                     view_number: 0,
//                     request_number: 0,
//                     result,
//                 };
//                 let serialized = bincode::serialize(&reply).unwrap();

//                 // Send the response (write the length-prefixed frame)
//                 framed.send(Bytes::from(serialized)).await.unwrap();
//             }
//             Err(_) => todo!(),
//         }
//     }
// }
