use std::collections::VecDeque;

use quickcheck::{Arbitrary, Gen};

use crate::{
    message::ClientRequest,
    operation::Operation,
    types::{OpNumber, ViewNumber},
};

#[derive(Clone, Debug, PartialEq, Eq, Default)]
pub struct Log {
    view: ViewNumber,
    start_op_number: OpNumber,
    end_op_number: OpNumber,
    pub entries: VecDeque<Operation>,
}

// impl Arbitrary for Log {
//     fn arbitrary(g: &mut Gen) -> Self {
//         let entries: VecDeque<Entry> = Arbitrary::arbitrary(g);
//         let checkpoint: OpNumber = Arbitrary::arbitrary(g);
//         Self {
//             entries,
//             checkpoint,
//         }
//     }
// }

impl Log {
    pub fn append(&mut self, view_number: ViewNumber, op: Operation) -> OpNumber {
        self.view = view_number;
        self.end_op_number += 1;
        if self.entries.is_empty() {
            self.start_op_number = self.end_op_number;
        }
        self.entries.push_back(op);
        self.end_op_number
    }

    // pub fn get_entry(&self, op_num: OpNumber) -> Option<&Entry> {
    //     match op_num <= self.checkpoint {
    //         true => None,
    //         false => self.entries.iter().find(|e| e.op_num == op_num),
    //     }
    // }

    // pub fn advance_checkpoint(&mut self, new_checkpoint: OpNumber) {
    //     assert!(
    //         new_checkpoint >= self.checkpoint,
    //         "Checkpoint cannot move backwards."
    //     );
    //     self.checkpoint = new_checkpoint;
    //     self.entries.retain(|e| e.op_num > self.checkpoint);
    // }

    // pub fn last_op_num(&self) -> Option<OpNumber> {
    //     self.entries.back().map(|e| e.op_num)
    // }

    // pub fn size(&self) -> usize {
    //     self.entries.len()
    // }
}

// #[cfg(test)]
// mod tests {

//     use super::*;

//     #[quickcheck]
//     fn test_append_increasing_op_nums(mut log: Log) -> bool {
//         let mut g = Gen::new(1);
//         let entry = Entry::arbitrary(&mut g);
//         if let None = log.last_op_num() {
//             return true;
//         }

//         if entry.op_num <= log.last_op_num().unwrap() {
//             return std::panic::catch_unwind(move || log.append_entry(entry.clone())).is_err();
//         } else {
//             log.append_entry(entry);
//             return true;
//         }
//     }
// }
