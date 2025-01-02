use std::net::SocketAddr;

#[derive(Debug)]
pub struct Configuration(Vec<SocketAddr>);

impl Configuration {
    pub fn new(addrs: Vec<&str>) -> Self {
        let mut c = Configuration(vec![]);
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
                _ => panic!("Could not parse SocketAddr"),
            };

            c.insert_sorted(parsed);
        }
        c
    }

    pub fn insert_sorted(&mut self, new_entry: SocketAddr) -> &mut Self {
        if let Some(index) = self.0.iter().position(|addr| &new_entry <= addr) {
            self.0.insert(index, new_entry);
        } else {
            self.0.push(new_entry);
        }
        self
    }

    pub fn remove(&mut self, t: &SocketAddr) -> &mut Self {
        self.0.retain(|addr| t != addr);
        self
    }

    pub fn find_addr(&mut self, addr: &SocketAddr) -> Option<usize> {
        self.0.iter().position(|a| addr == a)
    }
}

#[cfg(test)]
mod tests {
    use std::net::{IpAddr, Ipv4Addr};

    use super::*;
    fn addrs() -> Configuration {
        return Configuration::new(vec![
            "10.0.0.1:4444",
            "10.0.0.1:80",
            "127.0.0.1",
            "10.0.0.1:80",
            "192.168.0.1:8080",
            "127.0.0.1:9090",
            "10.0.0.1",
        ]);
    }

    #[test]
    fn add() {
        let mut addresses = addrs();
        let socket = SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 8080);
        addresses.insert_sorted(socket);
        assert!(addresses.0.len() == 8);
        assert_eq!(addresses.find_addr(&socket).unwrap(), 5);
    }

    #[test]
    fn remove() {
        let mut addresses = addrs();
        assert!(addresses.0.len() == 7);
        let socket = SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 9090);
        addresses.remove(&socket);
        assert!(addresses.0.len() == 6);
    }
}
