use core::result::Result;
use io_uring::squeue::PushError;
use io_uring::{cqueue, opcode, types, CompletionQueue};
use io_uring::{types::Fd, IoUring};
use log::debug;
use slab::Slab;
use std::borrow::Borrow;
use std::collections::VecDeque;
use std::net::{SocketAddr, TcpListener};
use std::os::fd::AsRawFd;
use std::os::unix::io::RawFd;
use std::{io, ptr};
struct Connection {
  fd: RawFd,
  state: CState,
  buffer: Vec<u8>,
}

struct Server {
  ring: IoUring,
  connections: Slab<Connection>,
  listener_fd: RawFd,
  backlog: VecDeque<u8>,
}

// State machine for connection state
#[derive(Debug)]
enum CState {
  Accepting,
  Reading,
  Writing,
  Closed,
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

pub fn start_server(addr: SocketAddr) -> () {
  let mut ring = IoUring::new(1024).unwrap();
  let listener = TcpListener::bind(addr).unwrap();
  listener.set_nonblocking(true).unwrap();

  //   let mut backlog = VecDeque::new();
  // let mut bufpool = Vec::with_capacity(256);
  let mut buf_alloc = Slab::with_capacity(256);
  //   let mut token_alloc = Slab::with_capacity(256);

  debug!("Listening on {:?}", listener.local_addr().unwrap());

  //   let (submitter, mut sq, mut cq) = ring.split();

  let mut server = Server {
    ring,
    connections: Slab::with_capacity(64),
    listener_fd: listener.as_raw_fd(),
    backlog: VecDeque::new(),
  };

  server.register_accept().unwrap();

  server.run().unwrap();
}

impl Server {
  pub fn run(&mut self) -> io::Result<()> {
    Ok(())
  }

  fn register_accept(&mut self) -> Result<(), IOError> {
    let entry = opcode::Accept::new(
      types::Fd(self.listener_fd),
      ptr::null_mut(),
      ptr::null_mut(),
    )
    .build();
    // .user_data(token as _);
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
    .build();

    unsafe { self.ring.submission().push(&entry) }?;
    self.ring.submit()?;

    Ok(())
  }

  pub fn handle_accept(&mut self, cqe: cqueue::Entry) -> Result<(), IOError> {
    let socket = cqe.result() as RawFd;
    let conn = Connection {
      fd: socket,
      state: CState::Reading,
      buffer: vec![0; 1024],
    };
    let conn_id = self.connections.insert(conn);

    self.register_read(conn_id)?;
    Ok(())
  }
}
