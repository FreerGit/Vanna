use bytes::Bytes;
use futures_util::{SinkExt, StreamExt};
use kek::{
    client::Client,
    configuration::Configuration,
    message::{ClientRequest, IOMessage, Reply},
    operation::{OpResult, Operation},
    replica::Replica,
    types::ReplicaID,
    utils,
};
use std::{
    io::{stdin, stdout, Write},
    net::SocketAddr,
    rc::Rc,
    time::Duration,
};
use tokio::{net::TcpListener, select, task::LocalSet};
use tokio::{net::TcpStream, time::sleep};
use tokio_util::codec::{Framed, LengthDelimitedCodec};
use utils::LOGGER;

use clap::{Arg, Command};

fn parse_command(input: &str, state: &Client) -> Option<ClientRequest> {
    let parts: Vec<&str> = input.split_whitespace().collect();
    let mut command = ClientRequest {
        client_id: state.client_id,
        request_number: state.request_number,
        op: Operation::Join,
    };
    match parts.as_slice() {
        ["Join"] => Some(command),
        ["Add", key, value] => {
            let key = Bytes::from(key.to_string());
            let value = Bytes::from(value.to_string());
            command.op = Operation::Add { key, value };
            Some(command)
        }
        ["Update", key, value] => {
            let key = Bytes::from(key.to_string());
            let value = Bytes::from(value.to_string());
            command.op = Operation::Update { key, value };
            Some(command)
        }
        ["Remove", key] => {
            let key = Bytes::from(key.to_string());
            command.op = Operation::Remove { key };
            Some(command)
        }
        _ => None,
    }
}

fn get_command(state: &Client) -> Option<ClientRequest> {
    // LOGGER.info(|| "> ");
    print!("> ");
    stdout().flush().unwrap();
    let mut input = String::new();
    match stdin().read_line(&mut input) {
        Ok(0) => None, // End of input (Ctrl+D)
        Ok(_) => parse_command(input.trim(), state),
        Err(_) => None,
    }
}

async fn start_client_with_stdin(saddr: SocketAddr) {
    LOGGER.info(|| "Client started, enter commands:");

    sleep(Duration::from_millis(10)).await;
    Client::start(saddr, get_command).await;
}

async fn handle_connection(r: Rc<Replica>, socket: TcpStream) {
    let mut framed = Framed::new(socket, LengthDelimitedCodec::new());
    loop {
        let frame = framed.next().await.unwrap();

        match frame {
            Ok(bytes) => {
                let message: IOMessage = bincode::deserialize(&bytes).unwrap();
                let pp = message.clone();
                LOGGER.info(move || format!("{:?}", pp));

                let result = match message {
                    IOMessage::ClientRequest(request) => match request.op {
                        Operation::Add { key, value } => todo!(),
                        Operation::Update { key, value } => todo!(),
                        Operation::Remove { key } => todo!(),
                        Operation::Join => OpResult::JoinResult(Ok(1)),
                    },
                    IOMessage::ReplicaMessage(replica) => todo!(),
                };
                let reply = Reply {
                    view_number: 0,
                    request_number: 0,
                    result,
                };
                let serialized = bincode::serialize(&reply).unwrap();

                // Send the response (write the length-prefixed frame)
                framed.send(Bytes::from(serialized)).await.unwrap();
            }
            Err(_) => todo!(),
        }
    }
}

async fn start_replica(r: Replica, addr: SocketAddr) {
    let listener = TcpListener::bind(addr).await.unwrap();
    let replica_rc = Rc::new(r.clone());

    let local_set = LocalSet::new();
    local_set
        .run_until(async move {
            loop {
                select! {
                    // Accept new connections
                    Ok((socket, _)) = listener.accept() => {
                        let c = Rc::clone(&replica_rc);
                        tokio::task::spawn_local(async move {
                            handle_connection(c, socket).await;
                        });
                    }

                    // Check for outgoing client messages
                    Some(reply) = r.dequeue_client_reply() => {
                        todo!()
                    }

                    // Check for outgoing replica messages
                    Some((addr, message)) = r.dequeue_replica_message() => {
                        todo!()
                    }
                }

                println!("KEKbbb");
            }
        })
        .await;
}

#[tokio::main(flavor = "current_thread")]
async fn main() {
    let matches = Command::new("Node CLI")
        .about("Client or Replica node")
        .arg_required_else_help(true)
        .subcommand(
            Command::new("run-client").about("Run a client").arg(
                Arg::new("primary")
                    .long("primary")
                    .required(true)
                    .help("Address to primary"),
            ),
        )
        .subcommand(
            Command::new("run-replica")
                .about("Run a replica")
                .arg(
                    Arg::new("addresses")
                        .long("addresses")
                        .required(true)
                        .help("All addresses"),
                )
                .arg(
                    Arg::new("replica")
                        .long("replica")
                        .required(true)
                        .help("This replica's index into addresses"),
                ),
        )
        .get_matches();

    if let Some(client_matches) = matches.subcommand_matches("run-client") {
        let primary = client_matches.get_one::<String>("primary").unwrap();
        let primary_sockaddr: SocketAddr = primary.parse().expect("SocketAddr");
        start_client_with_stdin(primary_sockaddr).await;
    } else if let Some(replica_matches) = matches.subcommand_matches("run-replica") {
        let addrs = replica_matches.get_one::<String>("addresses").unwrap();
        let replica_id: ReplicaID = replica_matches
            .get_one::<String>("replica")
            .unwrap()
            .parse()
            .unwrap();
        let seperated = String::as_str(addrs).split(',').collect();
        let conf = Configuration::new(seperated);
        let addr = conf.find_addr(replica_id);
        let replica = Replica::new(conf, replica_id);

        start_replica(replica, addr).await;
    }

    LOGGER.shutdown();
}
