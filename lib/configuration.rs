use std::net::SocketAddr;

use crate::types::{ReplicaID, ViewNumber};

#[derive(Clone, Debug, Default)]
pub struct Configuration {
    pub replicas: Vec<SocketAddr>,
}

impl Configuration {
    pub fn new(addrs: Vec<&str>) -> Self {
        let mut c = Configuration::default();
        for a in addrs {
            let parsed = match a.split_once(':') {
                None => {
                    let parsed_addr = a.parse().unwrap();
                    SocketAddr::new(parsed_addr, 80)
                }
                Some((addr, port)) => {
                    let parsed_addr = addr.parse().unwrap();
                    let parsed_port = port.parse().unwrap();
                    SocketAddr::new(parsed_addr, parsed_port)
                }
            };

            c.insert_sorted(parsed);
        }
        c
    }

    pub fn insert_sorted(&mut self, new_entry: SocketAddr) -> &mut Self {
        if let Some(index) = self.replicas.iter().position(|addr| &new_entry <= addr) {
            self.replicas.insert(index, new_entry);
        } else {
            self.replicas.push(new_entry);
        }
        self
    }

    pub fn remove(&mut self, t: &SocketAddr) -> &mut Self {
        self.replicas.retain(|addr| t != addr);
        self
    }

    pub fn get_id(&mut self, addr: &SocketAddr) -> Option<usize> {
        self.replicas.iter().position(|a| addr == a)
    }

    pub fn find_addr(&self, id: usize) -> SocketAddr {
        self.replicas[id]
    }

    pub fn primary_id(&self, view_number: ViewNumber) -> ReplicaID {
        view_number % self.replicas.len()
    }
}

// #[cfg(test)]
// mod tests {

//     use std::net::{IpAddr, Ipv4Addr};

//     use super::*;
//     fn addrs() -> Configuration {
//         return Configuration::new(vec![
//             "10.0.0.1:4444",
//             "10.0.0.1:80",
//             "127.0.0.1",
//             "10.0.0.1:80",
//             "192.168.0.1:8080",
//             "127.0.0.1:9090",
//             "10.0.0.1",
//         ]);
//     }

//     #[quickcheck]
//     fn quickcheck_sorted(addrs: Vec<SocketAddr>) -> bool {
//         let mut config = Configuration(vec![]);
//         for addr in addrs {
//             config.insert_sorted(addr);
//         }
//         config.0.is_sorted()
//     }

//     #[test]
//     fn add() {
//         let mut addresses = addrs();
//         let socket = SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 8080);
//         addresses.insert_sorted(socket);
//         assert!(addresses.0.len() == 8);
//         assert_eq!(addresses.get_id(&socket).unwrap(), 5);
//     }

//     #[test]
//     fn remove() {
//         let mut addresses = addrs();
//         assert!(addresses.0.len() == 7);
//         let socket = SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 9090);
//         addresses.remove(&socket);
//         assert!(addresses.0.len() == 6);
//     }
// }
