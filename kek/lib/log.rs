use std::collections::VecDeque;

use quickcheck::{Arbitrary, Gen};

use crate::message::ClientRequest;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Entry {
    op_num: u64,
    request: ClientRequest,
}

impl Arbitrary for Entry {
    fn arbitrary(g: &mut Gen) -> Self {
        let op_num: u64 = Arbitrary::arbitrary(g);
        let request: ClientRequest = Arbitrary::arbitrary(g);
        Self { op_num, request }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Log {
    entries: VecDeque<Entry>,
    checkpoint: u64,
}

impl Arbitrary for Log {
    fn arbitrary(g: &mut Gen) -> Self {
        let entries: VecDeque<Entry> = Arbitrary::arbitrary(g);
        let checkpoint: u64 = Arbitrary::arbitrary(g);
        Self {
            entries,
            checkpoint,
        }
    }
}

impl Log {
    pub fn new() -> Self {
        Self {
            entries: VecDeque::new(),
            checkpoint: 0,
        }
    }

    pub fn append_entry(&mut self, e: Entry) -> () {
        if let Some(last_entry) = self.entries.back() {
            assert!(e.op_num > last_entry.op_num, "must be increasing.");
        }
        self.entries.push_back(e);
    }

    pub fn get_entry(&self, op_num: u64) -> Option<&Entry> {
        match op_num <= self.checkpoint {
            true => None,
            false => self.entries.iter().find(|e| e.op_num == op_num),
        }
    }

    pub fn advance_checkpoint(&mut self, new_checkpoint: u64) {
        assert!(
            new_checkpoint >= self.checkpoint,
            "Checkpoint cannot move backwards."
        );
        self.checkpoint = new_checkpoint;
        self.entries.retain(|e| e.op_num > self.checkpoint);
    }

    pub fn last_op_num(&self) -> Option<u64> {
        self.entries.back().map(|e| e.op_num)
    }

    pub fn size(&self) -> usize {
        self.entries.len()
    }
}

#[cfg(test)]
mod tests {

    use super::*;

    #[quickcheck]
    fn test_append_increasing_op_nums(mut log: Log) -> bool {
        let mut g = Gen::new(1);
        let entry = Entry::arbitrary(&mut g);
        if let None = log.last_op_num() {
            return true;
        }

        if entry.op_num <= log.last_op_num().unwrap() {
            return std::panic::catch_unwind(move || log.append_entry(entry.clone())).is_err();
        } else {
            log.append_entry(entry);
            return true;
        }
    }
}
