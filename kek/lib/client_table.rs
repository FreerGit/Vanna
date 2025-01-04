use hashbrown::HashMap;

use crate::operation::OpResult;

#[derive(Clone, Debug, Default)]
pub struct Entry {
    last_request_id: u64,
    last_result: Option<OpResult>, // None implies not executed
}

#[derive(Clone, Debug)]
pub struct ClienTable {
    table: HashMap<u64, Entry>,
}

impl ClienTable {
    pub fn new() -> Self {
        Self {
            table: HashMap::new(),
        }
    }

    pub fn add_client(&mut self) -> u64 {
        let new_client = self.table.iter().max_by_key(|k| k.0).map_or(0, |k| k.0 + 1);
        self.table.insert(new_client, Entry::default());
        return new_client;
    }

    pub fn update_client(&mut self, id: u64, op_number: u64, result: Option<OpResult>) -> () {
        let update = self.table.insert(
            id,
            Entry {
                last_request_id: op_number,
                last_result: result,
            },
        );
        assert!(update.is_some());
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn add_client() {
        let mut ct = ClienTable::new();
        for i in 0..=10 {
            assert_eq!(ct.add_client(), i);
        }
    }

    #[test]
    fn update_client() {
        let mut ct = ClienTable::new();
        let id = ct.add_client();
        ct.update_client(id, 5, None);

        assert!(ct.table.get(&id).is_some());
    }

    #[test]
    #[should_panic]
    fn update_client_fails() {
        let mut ct = ClienTable::new();
        ct.update_client(0, 1, None);
    }
}
