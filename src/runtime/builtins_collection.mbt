///|
// SameValueZero comparison for Map/Set keys
fn same_value_zero(a : JSValue, b : JSValue) -> Bool {
  match (a, b) {
    (Number(x), Number(y)) =>
      if x.is_nan() && y.is_nan() {
        true
      } else if x == 0.0 && y == 0.0 {
        // +0 === -0 in SameValueZero
        true
      } else {
        x == y
      }
    (String(x), String(y)) => x == y
    (Bool(x), Bool(y)) => x == y
    (Undefined, Undefined) => true
    (Null, Null) => true
    // Reference equality for objects
    (Object(m1), Object(m2)) => m1.id == m2.id
    (JSValue::Array(a1), JSValue::Array(a2)) => a1.id == a2.id
    (Function(f1), Function(f2)) => f1.id == f2.id
    _ => false
  }
}

///|
fn JSInterpreter::map_get_entry(
  self : JSInterpreter,
  map_obj : JSValue,
  key : JSValue,
) -> JSValue {
  let _ = self
  match js_get_prop(map_obj, "__map_entries") {
    JSValue::Array(arr) => {
      for i = 0; i < arr.length; i = i + 1 {
        match arr.items[i] {
          JSValue::Array(pair) if pair.length >= 2 =>
            if same_value_zero(pair.items[0], key) {
              return pair.items[1]
            }
          _ => ()
        }
      }
      Undefined
    }
    _ => Undefined
  }
}

///|
fn JSInterpreter::map_set_entry(
  self : JSInterpreter,
  map_obj : JSValue,
  key : JSValue,
  value : JSValue,
) -> JSValue {
  let _ = self
  match js_get_prop(map_obj, "__map_entries") {
    JSValue::Array(arr) => {
      // Check if key exists
      for i = 0; i < arr.length; i = i + 1 {
        match arr.items[i] {
          JSValue::Array(pair) if pair.length >= 2 =>
            if same_value_zero(pair.items[0], key) {
              // Update existing entry
              let new_pair = js_new_array()
              let _ = js_array_push(new_pair, key)
              let _ = js_array_push(new_pair, value)
              arr.items[i] = new_pair
              return value
            }
          _ => ()
        }
      }
      // Add new entry
      let new_pair = js_new_array()
      let _ = js_array_push(new_pair, key)
      let _ = js_array_push(new_pair, value)
      let _ = js_array_push(JSValue::Array(arr), new_pair)

    }
    _ => ()
  }
  value
}

///|
fn JSInterpreter::map_has_entry(
  self : JSInterpreter,
  map_obj : JSValue,
  key : JSValue,
) -> Bool {
  let _ = self
  match js_get_prop(map_obj, "__map_entries") {
    JSValue::Array(arr) => {
      for i = 0; i < arr.length; i = i + 1 {
        match arr.items[i] {
          JSValue::Array(pair) if pair.length >= 2 =>
            if same_value_zero(pair.items[0], key) {
              return true
            }
          _ => ()
        }
      }
      false
    }
    _ => false
  }
}

///|
fn JSInterpreter::map_delete_entry(
  self : JSInterpreter,
  map_obj : JSValue,
  key : JSValue,
) -> Bool {
  let _ = self
  match js_get_prop(map_obj, "__map_entries") {
    JSValue::Array(arr) => {
      for i = 0; i < arr.length; i = i + 1 {
        match arr.items[i] {
          JSValue::Array(pair) if pair.length >= 2 =>
            if same_value_zero(pair.items[0], key) {
              let _ = arr.items.remove(i)
              arr.length = arr.length - 1
              return true
            }
          _ => ()
        }
      }
      false
    }
    _ => false
  }
}

///|
fn JSInterpreter::set_add_entry(
  self : JSInterpreter,
  set_obj : JSValue,
  value : JSValue,
) -> JSValue {
  let _ = self
  match js_get_prop(set_obj, "__set_entries") {
    JSValue::Array(arr) => {
      // Check if value exists
      for i = 0; i < arr.length; i = i + 1 {
        if same_value_zero(arr.items[i], value) {
          return value
        }
      }
      // Add new entry
      let _ = js_array_push(JSValue::Array(arr), value)

    }
    _ => ()
  }
  value
}

///|
fn JSInterpreter::set_has_entry(
  self : JSInterpreter,
  set_obj : JSValue,
  value : JSValue,
) -> Bool {
  let _ = self
  match js_get_prop(set_obj, "__set_entries") {
    JSValue::Array(arr) => {
      for i = 0; i < arr.length; i = i + 1 {
        if same_value_zero(arr.items[i], value) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn JSInterpreter::set_delete_entry(
  self : JSInterpreter,
  set_obj : JSValue,
  value : JSValue,
) -> Bool {
  let _ = self
  match js_get_prop(set_obj, "__set_entries") {
    JSValue::Array(arr) => {
      for i = 0; i < arr.length; i = i + 1 {
        if same_value_zero(arr.items[i], value) {
          let _ = arr.items.remove(i)
          arr.length = arr.length - 1
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn JSInterpreter::new_map_key_iterator(
  self : JSInterpreter,
  map_obj : JSValue,
) -> JSValue {
  let iter = self.new_object()
  let _ = js_set_prop(iter, "__map_ref", map_obj)
  let _ = js_set_prop(iter, "__iter_index", Number(0.0))
  let _ = js_set_prop(iter, "__iter_kind", String("key"))
  let next_fn = self.make_native("MapIterator.next")
  let _ = js_set_prop(iter, "next", next_fn)
  let iter_self_fn = self.make_native("Iterator.self")
  let _ = js_set_prop(iter, "@@iterator", iter_self_fn)
  iter
}

///|
fn JSInterpreter::new_map_value_iterator(
  self : JSInterpreter,
  map_obj : JSValue,
) -> JSValue {
  let iter = self.new_object()
  let _ = js_set_prop(iter, "__map_ref", map_obj)
  let _ = js_set_prop(iter, "__iter_index", Number(0.0))
  let _ = js_set_prop(iter, "__iter_kind", String("value"))
  let next_fn = self.make_native("MapIterator.next")
  let _ = js_set_prop(iter, "next", next_fn)
  let iter_self_fn = self.make_native("Iterator.self")
  let _ = js_set_prop(iter, "@@iterator", iter_self_fn)
  iter
}

///|
fn JSInterpreter::new_map_entry_iterator(
  self : JSInterpreter,
  map_obj : JSValue,
) -> JSValue {
  let iter = self.new_object()
  let _ = js_set_prop(iter, "__map_ref", map_obj)
  let _ = js_set_prop(iter, "__iter_index", Number(0.0))
  let _ = js_set_prop(iter, "__iter_kind", String("entry"))
  let next_fn = self.make_native("MapIterator.next")
  let _ = js_set_prop(iter, "next", next_fn)
  let iter_self_fn = self.make_native("Iterator.self")
  let _ = js_set_prop(iter, "@@iterator", iter_self_fn)
  iter
}

///|
fn JSInterpreter::new_set_value_iterator(
  self : JSInterpreter,
  set_obj : JSValue,
) -> JSValue {
  let iter = self.new_object()
  let _ = js_set_prop(iter, "__set_ref", set_obj)
  let _ = js_set_prop(iter, "__iter_index", Number(0.0))
  let _ = js_set_prop(iter, "__iter_kind", String("value"))
  let next_fn = self.make_native("SetIterator.next")
  let _ = js_set_prop(iter, "next", next_fn)
  let iter_self_fn = self.make_native("Iterator.self")
  let _ = js_set_prop(iter, "@@iterator", iter_self_fn)
  iter
}

///|
fn JSInterpreter::new_set_entry_iterator(
  self : JSInterpreter,
  set_obj : JSValue,
) -> JSValue {
  let iter = self.new_object()
  let _ = js_set_prop(iter, "__set_ref", set_obj)
  let _ = js_set_prop(iter, "__iter_index", Number(0.0))
  let _ = js_set_prop(iter, "__iter_kind", String("entry"))
  let next_fn = self.make_native("SetIterator.next")
  let _ = js_set_prop(iter, "next", next_fn)
  let iter_self_fn = self.make_native("Iterator.self")
  let _ = js_set_prop(iter, "@@iterator", iter_self_fn)
  iter
}
