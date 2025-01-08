use hashbrown::HashMap;

use crate::{
  operation::OpResult,
  types::{ClientID, OpNumber},
};

#[derive(Clone, Debug, Default)]
pub struct Entry {
  pub last_request_id: ClientID,
  pub last_result: Option<OpResult>, // None implies not executed
}

#[derive(Clone, Debug, Default)]
pub struct ClienTable {
  table: HashMap<ClientID, Entry>,
}

impl ClienTable {
  pub fn add_client(&mut self) -> ClientID {
    let new_client = self.table.iter().max_by_key(|k| k.0).map_or(1, |k| k.0 + 1);
    self.table.insert(new_client, Entry::default());
    new_client
  }

  pub fn find_client(&self, id: ClientID) -> Option<&Entry> {
    self.table.get(&id)
  }

  pub fn update_client(&mut self, id: ClientID, op_number: OpNumber, result: Option<OpResult>) {
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
    let mut ct = ClienTable::default();
    for i in 1..=10 {
      assert_eq!(ct.add_client(), i);
    }
  }

  #[test]
  fn update_client() {
    let mut ct = ClienTable::default();
    let id = ct.add_client();
    ct.update_client(id, 5, None);

    assert!(ct.table.get(&id).is_some());
  }

  #[test]
  #[should_panic]
  fn update_client_fails() {
    let mut ct = ClienTable::default();
    ct.update_client(0, 1, None);
  }
}
