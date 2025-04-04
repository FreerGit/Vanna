use core::panic;
use std::{
  io::{Error, ErrorKind, Read, Write},
  net::{SocketAddr, TcpListener, TcpStream},
};

use hashbrown::HashMap;

use crate::{
  message::IOMessage,
  replica::Replica,
  types::{ClientID, ConnectionID},
};

pub type ConnectionTable = HashMap<ClientID, ConnectionID>;

fn read_exact(s: &mut Vec<u8>, buf: &mut [u8]) -> Result<(), Error> {
  let mut pos = 0;

  while pos < buf.len() {
    if s.is_empty() {
      panic!("TODO");
      // return Err(Error::new(ErrorKind::UnexpectedEof, "buffer too small"));
    }

    let chunk_size = std::cmp::min(s.len(), buf.len() - pos);
    buf[pos..pos + chunk_size].copy_from_slice(&s[..chunk_size]);
    s.drain(..chunk_size);
    pos += chunk_size;
  }

  Ok(())
}

fn write_all(s: &mut TcpStream, buf: &[u8]) -> Result<(), Error> {
  let mut pos = 0;
  while pos < buf.len() {
    match s.write(&buf[pos..]) {
      Ok(0) => return Err(Error::new(ErrorKind::WriteZero, "connection closed")),
      Ok(n) => pos += n,
      Err(e) if e.kind() == ErrorKind::WouldBlock => continue,
      Err(e) if e.kind() == ErrorKind::Interrupted => continue,
      Err(e) => return Err(e),
    }
  }
  s.flush()?;
  Ok(())
}

pub fn read_message(s: &mut Vec<u8>) -> Result<IOMessage, Error> {
  let mut header = [0u8; 4];
  read_exact(s, &mut header)?;

  let msg_size: usize = u32::from_be_bytes(header)
    .try_into()
    .map_err(|e| Error::new(ErrorKind::InvalidData, e))?;

  let mut buf = vec![0u8; msg_size];
  read_exact(s, &mut buf)?;

  bincode::deserialize(&buf).map_err(|e| Error::new(ErrorKind::InvalidData, e))
}

pub fn write_message(s: &mut TcpStream, msg: &IOMessage) -> Result<(), Error> {
  let serialized = bincode::serialize(msg).map_err(|e| Error::new(ErrorKind::InvalidData, e))?;

  let header = (serialized.len() as u32).to_be_bytes();

  let mut buf = Vec::with_capacity(serialized.len() + 4);
  buf.extend_from_slice(&header);
  buf.extend_from_slice(&serialized);

  write_all(s, &buf)
}

// async fn handle_connection(
//   replica: Arc<Mutex<Replica>>,
//   s: (TcpStream, SocketAddr),
// ) -> Result<(), Error> {
//   loop {
//     let msg = read_message(&mut s.0.try_clone().unwrap())?;

//     match msg {
//       IOMessage::Client(req) => {
//         replica
//           .lock()
//           .unwrap()
//           .on_client_request(req, s.0.try_clone().unwrap());

//         // if let Some(resp) = response {
//         //   conn.write_message(&resp).await?;
//         // }
//       }

//       IOMessage::Replica(msg) => replica.lock().unwrap().on_replica_message(msg),
//       IOMessage::Reply(_) => todo!(),
//     }

//     // Process outgoing messages
//     let replica_m = {
//       let mut replica = replica.lock().unwrap();
//       replica.dequeue_replica_msg()
//     };

//     for (addr, msg) in replica_m {
//       let mut connection =
//         tokio::task::block_in_place(|| TcpStream::connect(addr).expect("failed to connect"));
//       write_message(&mut connection, &IOMessage::Replica(msg)).unwrap();
//     }
//   }
// }

// pub async fn start_io_layer(replica: Replica, addr: SocketAddr) {
//   let listener = TcpListener::bind(addr).unwrap();
//   let replica_rc = Arc::new(Mutex::new(replica.clone()));

//   // let local_set = LocalSet::new();

//   let _ = tokio::spawn(async move {
//     loop {
//       let conn = block_in_place(|| listener.accept()).unwrap();

//       let cloned = Arc::clone(&replica_rc);
//       tokio::task::spawn(async move {
//         let _ = handle_connection(cloned, conn).await;
//       });
//     }
//   })
//   .await;
// }
