use bytes::Bytes;
use hashbrown::HashMap;

#[derive(Clone, Debug, Default)]
pub struct KVStore {
  store: HashMap<Bytes, Bytes>,
}

impl KVStore {
  pub fn set(&mut self, k: Bytes, v: Bytes) {
    let i = self.store.insert(k, v);
    assert!(i.is_none())
  }

  pub fn get(&self, k: Bytes) -> Option<&Bytes> {
    match self.store.get(&k) {
      Some(v) => Some(v),
      None => todo!(),
    }
  }

  pub fn remove(&mut self, k: Bytes) {
    match self.store.remove(&k) {
      Some(_) => (),
      None => todo!(),
    }
  }
}

// open! Core

// module BytesKey = struct
//   type t = Bytes.t [@@deriving compare, sexp]

//   let hash = Hashtbl.hash
// end

// type t = (BytesKey.t, Bytes.t) Hashtbl.t [@@deriving sexp_of]

// let create () : t = Hashtbl.create (module BytesKey)
// let set store ~key ~value = Hashtbl.set store ~key ~data:value
// let get store ~key = Hashtbl.find store key
// let remove store ~key = Hashtbl.remove store key
