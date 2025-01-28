use core::result::Result;
use core::time;
use io_uring::cqueue::Entry;
use io_uring::opcode::{Accept, Socket};
use io_uring::squeue::PushError;
use io_uring::{cqueue, opcode, types, CompletionQueue};
use io_uring::{types::Fd, IoUring};
use log::debug;
use slab::Slab;
use std::collections::VecDeque;
use std::net::{SocketAddr, TcpListener};
use std::os::fd::{AsRawFd, IntoRawFd};
use std::os::unix::io::RawFd;
use std::thread::sleep;
use std::time::Duration;
use std::{io, ptr};

struct Connection {
  fd: RawFd,
  state: CState,
  buffer: Vec<u8>,
}

pub struct Server {
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

impl Server {
  pub fn new(addr: SocketAddr) -> Self {
    let ring = IoUring::new(1024).unwrap();
    let listener = TcpListener::bind(addr).unwrap();
    listener.set_nonblocking(true).unwrap();

    debug!("Listening on {:?}", listener.local_addr().unwrap());
    Server {
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
        if let Err(err) = self.handle_event(cqe) {
          panic!("{:?}", err);
        }
      }

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

  pub fn handle_accept(&mut self, cqe: cqueue::Entry) -> Result<(), IOError> {
    let socket = cqe.result() as RawFd;
    let conn = Connection {
      fd: socket,
      state: CState::Reading,
      buffer: vec![0; 1024],
    };
    let conn_id = self.connections.insert(conn);

    self.register_read(conn_id)?; // Register a read on current connection
    self.register_accept()?; // Make sure we still accept new connections
    Ok(())
  }

  fn handle_event(&mut self, cqe: cqueue::Entry) -> Result<(), IOError> {
    debug!("Event {:?}", cqe);
    let result = cqe.result();

    if result < 0 {
      let err = io::Error::from_raw_os_error(-result);
      debug!("CQE error: {:?}", err);
      return Err(IOError::IoError(err));
    }
    let conn_id = cqe.user_data();
    match conn_id {
      0 => self.handle_accept(cqe)?,
      _ => self.handle_connection_event((conn_id - 1) as usize, cqe)?,
    }

    Ok(())
  }

  fn handle_connection_event(&mut self, conn_id: usize, cqe: cqueue::Entry) -> Result<(), IOError> {
    let conn = &mut self.connections[conn_id];
    let result = cqe.result();
    match conn.state {
      CState::Reading => {
        debug!("buffer: {}", String::from_utf8_lossy(&conn.buffer.clone()));
        self.register_read(conn_id)?;
      }
      CState::Writing => todo!(),
    }
    Ok(())
  }
}
