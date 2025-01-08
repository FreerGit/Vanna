use bytes::Bytes;
use quickcheck::{Arbitrary, Gen};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum Operation {
  Add { key: Bytes, value: Bytes },
  Update { key: Bytes, value: Bytes },
  Remove { key: Bytes },
  Join,
}

impl Arbitrary for Operation {
  fn arbitrary(g: &mut Gen) -> Self {
    match u8::arbitrary(g) % 4 {
      0 => Operation::Add {
        key: Bytes::from(Vec::<u8>::arbitrary(g)),
        value: Bytes::from(Vec::<u8>::arbitrary(g)),
      },
      1 => Operation::Update {
        key: Bytes::from(Vec::<u8>::arbitrary(g)),
        value: Bytes::from(Vec::<u8>::arbitrary(g)),
      },
      2 => Operation::Remove {
        key: Bytes::from(Vec::<u8>::arbitrary(g)),
      },
      _ => Operation::Join,
    }
  }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum OpResult {
  AddResult(Result<(), ()>),     // TODO: error type
  UpdateResult(Result<(), ()>),  // TODO: error type
  RemoveResult(Result<(), ()>),  // TODO: error type
  JoinResult(Result<usize, ()>), // TODO: error type
  Outdated,
}
