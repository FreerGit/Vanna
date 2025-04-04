use core::time;
use std::{
  io::{self, Error, ErrorKind},
  net::{SocketAddr, TcpListener},
  os::fd::{IntoRawFd, RawFd},
  ptr,
  thread::sleep,
};

use io_uring::{
  cqueue::{self, Entry},
  opcode,
  squeue::PushError,
  types, IoUring,
};
use log::debug;
use slab::Slab;

use crate::{
  message::IOMessage,
  replica::Replica,
  types::{ClientID, ReplicaID},
};

pub struct Connection {
  peer: Option<PeerType>,
  fd: RawFd,
  state: CState,
  buffer: Vec<u8>,
}

pub enum PeerType {
  Unknown,
  Client(ClientID),
  Replica(ReplicaID),
}

pub struct MessageBus {
  ring: IoUring,

  connections: Slab<Connection>,

  listener_fd: RawFd,
  // backlog: VecDeque<u8>,
}

// State machine for connection state
#[derive(Debug)]
enum CState {
  Reading,
  Writing,
}

#[derive(Debug)]
pub enum IOError {
  PushError(PushError),
  IoError(io::Error),
}

impl From<PushError> for IOError {
  fn from(err: PushError) -> IOError {
    IOError::PushError(err)
  }
}

impl From<io::Error> for IOError {
  fn from(err: io::Error) -> IOError {
    IOError::IoError(err)
  }
}

impl MessageBus {
  pub fn new(addr: SocketAddr, replica: Replica) -> Self {
    let ring = IoUring::new(1024).unwrap();
    let listener = TcpListener::bind(addr).unwrap();
    listener.set_nonblocking(true).unwrap();

    debug!("Listening on {:?}", listener.local_addr().unwrap());
    MessageBus {
      ring,
      connections: Slab::with_capacity(64),
      listener_fd: listener.into_raw_fd(),
      // backlog: VecDeque::new(),
    }
  }

  pub fn run(&mut self) -> io::Result<()> {
    self.register_accept().unwrap();

    loop {
      self.ring.submit().unwrap();
      let cqes: Vec<Entry> = self.ring.completion().collect();
      for cqe in cqes {
        // if let Err(err) = self.handle_event(cqe) {
        //   panic!("{:?}", err);
        // }
      }

      // while let Some((replica_id, msg)) = self.replica.dequeue_replica_msg() {
      //   self
      // }

      sleep(time::Duration::from_millis(1));
    }
  }

  fn register_accept(&mut self) -> Result<(), IOError> {
    let entry = opcode::Accept::new(
      types::Fd(self.listener_fd),
      ptr::null_mut(),
      ptr::null_mut(),
    )
    .build()
    .user_data(0);
    unsafe { self.ring.submission().push(&entry)? };
    Ok(())
  }

  fn register_read(&mut self, conn_id: usize) -> Result<(), IOError> {
    let conn = &mut self.connections[conn_id];
    let entry = opcode::Read::new(
      types::Fd(conn.fd),
      conn.buffer.as_mut_ptr(),
      conn.buffer.len() as u32,
    )
    .build()
    .user_data((conn_id + 1) as u64);

    unsafe { self.ring.submission().push(&entry) }?;
    self.ring.submit()?;

    Ok(())
  }

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

  pub fn read_message(s: &mut Vec<u8>) -> Result<IOMessage, Error> {
    let mut header = [0u8; 4];
    Self::read_exact(s, &mut header)?;

    let msg_size: usize = u32::from_be_bytes(header)
      .try_into()
      .map_err(|e| Error::new(ErrorKind::InvalidData, e))?;

    let mut buf = vec![0u8; msg_size];
    Self::read_exact(s, &mut buf)?;

    bincode::deserialize(&buf).map_err(|e| Error::new(ErrorKind::InvalidData, e))
  }

  pub fn handle_accept(&mut self, cqe: cqueue::Entry) -> Result<(), IOError> {
    let socket = cqe.result() as RawFd;
    let conn = Connection {
      fd: socket,
      state: CState::Reading,
      buffer: vec![0; 1024],
      peer: None,
    };
    let conn_id = self.connections.insert(conn);

    self.register_read(conn_id)?; // Register a read on current connection
    self.register_accept()?; // Make sure we still accept new connections
    Ok(())
  }

  // fn handle_event(&mut self, cqe: cqueue::Entry) -> Result<(), IOError> {
  //   debug!("Event {:?}", cqe);
  //   let result = cqe.result();

  //   if result < 0 {
  //     let err = io::Error::from_raw_os_error(-result);
  //     debug!("CQE error: {:?}", err);
  //     return Err(IOError::IoError(err));
  //   }
  //   let conn_id = cqe.user_data();
  //   debug!("Conn id: {}", conn_id);
  //   match conn_id {
  //     0 => self.handle_accept(cqe)?,
  //     _ => self.handle_connection_event((conn_id - 1) as usize, cqe)?,
  //   }

  //   Ok(())
  // }

  // fn handle_connection_event(&mut self, conn_id: usize, cqe: cqueue::Entry) -> Result<(), IOError> {
  //   let conn = &mut self.connections[conn_id];
  //   let result = cqe.result();
  //   match conn.state {
  //     CState::Reading => {
  //       let msg = Self::read_message(&mut conn.buffer).unwrap();
  //       self.register_read(conn_id)?; // Continue reading after this
  //       debug!("msg: {:?}", msg);
  //       // debug!("buffer: {}", String::from_utf8_lossy(&conn.buffer.clone()));

  //       match msg {
  //         IOMessage::Client(req) => {
  //           self.replica.on_client_request(req, conn_id);
  //           // replica
  //           //   .lock()
  //           //   .unwrap()
  //           //   .on_client_request(req, s.0.try_clone().unwrap());

  //           // if let Some(resp) = response {
  //           //   conn.write_message(&resp).await?;
  //           // }
  //         }

  //         IOMessage::Replica(msg) => todo!(),
  //         IOMessage::Reply(_) => todo!(),
  //       }
  //     }
  //     CState::Writing => todo!(),
  //   }
  //   Ok(())
  // }
}
