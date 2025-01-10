use std::{
  cell::RefCell,
  io::{Read, Write},
  mem::transmute,
  net::{SocketAddr, TcpListener, TcpStream},
  rc::Rc,
  sync::{Arc, Mutex},
};

use hashbrown::HashMap;
use log::debug;
use tokio::task::{block_in_place, LocalSet};

use crate::{message::IORequest, replica::Replica, types::ClientID};

pub type ConnectionTable = Arc<Mutex<HashMap<ClientID, TcpStream>>>;

pub async fn read_with_header(stream: &mut TcpStream) -> IORequest {
  debug!("in read");
  let mut header = [0; 4];
  stream.read_exact(&mut header).unwrap();
  let msg_size: usize = u32::from_be_bytes(header).try_into().unwrap();
  debug!("read header {}", msg_size);
  let mut buf = vec![0; msg_size];
  stream.read_exact(buf.as_mut_slice()).unwrap();
  bincode::deserialize(&buf).unwrap()
}

pub fn write_with_header(s: &mut TcpStream, msg: IORequest) {
  let serialized = bincode::serialize(&msg).unwrap();
  let msg_size: u32 = serialized.len().try_into().unwrap();
  let header: [u8; 4] = unsafe { transmute(msg_size.to_be()) };
  let mut buf: Vec<u8> = Vec::with_capacity(serialized.len() + 4);
  buf.extend_from_slice(&header);
  buf.extend_from_slice(&serialized);
  debug!("{:?}", buf);

  s.write(&buf).unwrap(); // TODO
}

async fn handle_connection(replica: Arc<Mutex<Replica>>, s: (TcpStream, SocketAddr)) {
  loop {
    debug!("Iter");

    match read_with_header(&mut s.0.try_clone().unwrap()).await {
      IORequest::Client(client_request) => {
        debug!("{:?}", client_request);
        replica
          .lock()
          .unwrap()
          .on_client_request(client_request, s.0.try_clone().unwrap());
      }
      IORequest::Replica(replica_message) => {
        replica.lock().unwrap().on_replica_message(replica_message)
      }
    }

    while let Some((addr, msg)) = replica.lock().unwrap().dequeue_replica_msg() {
      let mut connection =
        tokio::task::block_in_place(|| TcpStream::connect(addr).expect("failed to connect"));
      write_with_header(&mut connection, IORequest::Replica(msg));
      debug!("Sent to replica");
    }

    // match framed.next().await {
    //   None => {
    //     warn!("Connect lost");
    //     break;
    //   }
    //   Some(Err(_)) => todo!(),
    //   Some(Ok(bytes)) => {
    //     let mut replica = replica.borrow_mut();
    //     debug!("{:?}", message);

    //     match message {
    //       IORequest::Client(r) => {
    //         // clients
    //         //   .lock()
    //         //   .unwrap()
    //         //   .insert(r.client_id, framed.into_inner().);
    //         replica.on_client_request(r)
    //       }
    //       IORequest::Replica(m) => replica.on_replica_message(m),
    //     }

    //     // // Respond to client
    //     // debug!("HERE");

    //     // debug!("HERE1");
    //     // Send to replicas

    //   }
    // }
  }
}

pub async fn start_io_layer(replica: Replica, addr: SocketAddr) {
  let listener = TcpListener::bind(addr).unwrap();
  let replica_rc = Arc::new(Mutex::new(replica.clone()));

  // let local_set = LocalSet::new();

  let _ = tokio::spawn(async move {
    loop {
      let conn = block_in_place(|| listener.accept()).unwrap();

      let cloned = Arc::clone(&replica_rc);
      tokio::task::spawn(async move {
        handle_connection(cloned, conn).await;
      });
    }
  })
  .await;
}
