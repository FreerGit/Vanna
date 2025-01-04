use bytes::Bytes;
use kek::{
    client::Client,
    configuration::Configuration,
    message::{Message, Request},
    operation::Operation,
    replica::{self, Replica},
    utils,
};
use std::{
    io::{stdin, stdout, Write},
    net::SocketAddr,
    sync,
    thread::sleep,
    time::Duration,
};
use utils::LOGGER;

use clap::{Arg, Command};

fn parse_command(input: &str, state: &Client) -> Option<Message> {
    let parts: Vec<&str> = input.split_whitespace().collect();
    let mut command = Request {
        client_id: state.client_id,
        request_number: state.request_number,
        op: Operation::Join,
    };
    match parts.as_slice() {
        ["Join"] => Some(Message::ClientRequest(command)),
        ["Add", key, value] => {
            let key = Bytes::from(key.to_string());
            let value = Bytes::from(value.to_string());
            command.op = Operation::Add { key, value };
            Some(Message::ClientRequest(command))
        }
        ["Update", key, value] => {
            let key = Bytes::from(key.to_string());
            let value = Bytes::from(value.to_string());
            command.op = Operation::Update { key, value };
            Some(Message::ClientRequest(command))
        }
        ["Remove", key] => {
            let key = Bytes::from(key.to_string());
            command.op = Operation::Remove { key };
            Some(Message::ClientRequest(command))
        }
        _ => None,
    }
}

fn get_command(state: &Client) -> Option<Message> {
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

    sleep(Duration::from_millis(10));
    Client::start(saddr, get_command).await;
}

#[tokio::main]
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
        let replica_id: usize = replica_matches
            .get_one::<String>("replica")
            .unwrap()
            .parse()
            .unwrap();
        let seperated = String::as_str(addrs).split(',').collect();
        let conf = Configuration::new(seperated);
        Replica::start(conf, replica_id).await;
    }

    LOGGER.shutdown();
}
