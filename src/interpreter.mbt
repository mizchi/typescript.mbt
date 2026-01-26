// JSValue インタプリタ
// ASTを直接解釈実行する

///|
/// インタプリタ
pub struct JSInterpreter {
  global_env : JSEnv
  mut last_error : JSValue?
  mut steps : Int
  step_limit : Int
}

///|
/// インタプリタを作成
pub fn JSInterpreter::new() -> JSInterpreter {
  let env = js_new_env(None)
  let interp = { global_env: env, last_error: None, steps: 0, step_limit: 1_000_000 }
  interp.install_builtins()
  interp
}

///|
/// ネイティブ関数を作成
fn make_native(env : JSEnv, name : String) -> JSValue {
  JSValue::Function({ params: [], body: Native(name), env })
}

///|
/// エラーオブジェクトを作成して保持
fn JSInterpreter::set_error(self : JSInterpreter, message : String) -> JSValue {
  let obj = js_new_object()
  let _ = js_set_prop(obj, "error", JSValue::String(message))
  self.last_error = Some(obj)
  obj
}

///|
/// 実行ステップをカウントして暴走を抑制
fn JSInterpreter::tick(self : JSInterpreter) -> Unit {
  match self.last_error {
    Some(_) => ()
    None => {
      self.steps += 1
      if self.steps > self.step_limit {
        let _ = self.set_error("Step limit exceeded")
      }
    }
  }
}

///|
/// エラーを取得してクリア
fn JSInterpreter::take_error(self : JSInterpreter) -> JSValue? {
  match self.last_error {
    Some(err) => {
      self.last_error = None
      Some(err)
    }
    None => None
  }
}

///|
/// グローバル組み込みをセットアップ
fn JSInterpreter::install_builtins(self : JSInterpreter) -> Unit {
  let global_obj = js_new_object()

  // console
  let console = js_new_object()
  let _ = js_set_prop(console, "log", make_native(self.global_env, "console.log"))
  self.global_env.define("console", console)
  let _ = js_set_prop(global_obj, "console", console)

  // Math
  let math = js_new_object()
  let _ = js_set_prop(math, "floor", make_native(self.global_env, "Math.floor"))
  let _ = js_set_prop(math, "ceil", make_native(self.global_env, "Math.ceil"))
  let _ = js_set_prop(math, "abs", make_native(self.global_env, "Math.abs"))
  let _ = js_set_prop(math, "sqrt", make_native(self.global_env, "Math.sqrt"))
  let _ = js_set_prop(math, "min", make_native(self.global_env, "Math.min"))
  let _ = js_set_prop(math, "max", make_native(self.global_env, "Math.max"))
  let _ = js_set_prop(math, "round", make_native(self.global_env, "Math.round"))
  let _ = js_set_prop(math, "random", make_native(self.global_env, "Math.random"))
  self.global_env.define("Math", math)
  let _ = js_set_prop(global_obj, "Math", math)

  // assert (callable object)
  let assert_obj = js_new_object()
  let _ = js_set_prop(assert_obj, "$call", make_native(self.global_env, "assert"))
  let _ = js_set_prop(
    assert_obj,
    "sameValue",
    make_native(self.global_env, "assert.sameValue"),
  )
  let _ = js_set_prop(
    assert_obj,
    "notSameValue",
    make_native(self.global_env, "assert.notSameValue"),
  )
  let _ = js_set_prop(
    assert_obj,
    "compareArray",
    make_native(self.global_env, "assert.compareArray"),
  )
  self.global_env.define("assert", assert_obj)
  let _ = js_set_prop(global_obj, "assert", assert_obj)

  // print
  let print_fn = make_native(self.global_env, "print")
  self.global_env.define("print", print_fn)
  let _ = js_set_prop(global_obj, "print", print_fn)

  // $DONOTEVALUATE
  let donotevaluate_fn = make_native(self.global_env, "$DONOTEVALUATE")
  self.global_env.define("$DONOTEVALUATE", donotevaluate_fn)
  let _ = js_set_prop(global_obj, "$DONOTEVALUATE", donotevaluate_fn)

  // $ERROR / $DONE
  let error_fn = make_native(self.global_env, "$ERROR")
  self.global_env.define("$ERROR", error_fn)
  let _ = js_set_prop(global_obj, "$ERROR", error_fn)
  let done_fn = make_native(self.global_env, "$DONE")
  self.global_env.define("$DONE", done_fn)
  let _ = js_set_prop(global_obj, "$DONE", done_fn)

  // $262
  let t262 = js_new_object()
  let _ = js_set_prop(t262, "global", global_obj)
  let _ = js_set_prop(t262, "evalScript", make_native(self.global_env, "$262.evalScript"))
  self.global_env.define("$262", t262)
  let _ = js_set_prop(global_obj, "$262", t262)

  // globalThis / global
  self.global_env.define("globalThis", global_obj)
  self.global_env.define("global", global_obj)
}

///|
/// 式を評価
pub fn JSInterpreter::eval_expr(
  self : JSInterpreter,
  expr : TsExpr,
  env : JSEnv,
) -> JSValue {
  self.tick()
  match expr {
    IntLit(n) => Number(n.to_double())
    NumberLit(n) => Number(n)
    BoolLit(b) => Bool(b)
    StringLit(s) => String(s)
    NullLit => Null
    Var(name) => env.get(name)
    BinOp(op, left, right) => {
      let lval = self.eval_expr(left, env)
      let rval = self.eval_expr(right, env)
      match op {
        Add => js_add(lval, rval)
        Sub => js_sub(lval, rval)
        Mul => js_mul(lval, rval)
        Div => js_div(lval, rval)
        Mod => js_mod(lval, rval)
        BinLt => js_lt(lval, rval)
        BinLe => js_le(lval, rval)
        BinGt => js_gt(lval, rval)
        BinGe => js_ge(lval, rval)
        BinEq => js_strict_eq(lval, rval) // === (strict equality)
        BinNe => js_strict_ne(lval, rval) // !== (strict inequality)
        AbstractEq => js_eq(lval, rval) // == (abstract equality)
        AbstractNe => js_ne(lval, rval) // != (abstract inequality)
        Instanceof => Bool(false)
        And =>
          // 短絡評価: lvalがfalsyならlval、そうでなければrval
          if lval.to_boolean() {
            rval
          } else {
            lval
          }
        Or =>
          // 短絡評価: lvalがtruthyならlval、そうでなければrval
          if lval.to_boolean() {
            lval
          } else {
            rval
          }
      }
    }
    UnaryOp(op, operand) =>
      match op {
        PreInc =>
          // ++x: インクリメントして新しい値を返す
          match operand {
            Var(name) => {
              let old_val = env.get(name)
              let new_val = js_add(old_val, Number(1.0))
              let _ = env.set(name, new_val)
              new_val
            }
            _ => {
              let val = self.eval_expr(operand, env)
              js_add(val, Number(1.0))
            }
          }
        PreDec =>
          // --x: デクリメントして新しい値を返す
          match operand {
            Var(name) => {
              let old_val = env.get(name)
              let new_val = js_sub(old_val, Number(1.0))
              let _ = env.set(name, new_val)
              new_val
            }
            _ => {
              let val = self.eval_expr(operand, env)
              js_sub(val, Number(1.0))
            }
          }
        PostInc =>
          // x++: 古い値を返してからインクリメント
          match operand {
            Var(name) => {
              let old_val = env.get(name)
              let new_val = js_add(old_val, Number(1.0))
              let _ = env.set(name, new_val)
              old_val
            }
            _ => {
              let val = self.eval_expr(operand, env)
              val // 副作用なし
            }
          }
        PostDec =>
          // x--: 古い値を返してからデクリメント
          match operand {
            Var(name) => {
              let old_val = env.get(name)
              let new_val = js_sub(old_val, Number(1.0))
              let _ = env.set(name, new_val)
              old_val
            }
            _ => {
              let val = self.eval_expr(operand, env)
              val // 副作用なし
            }
          }
        Neg => js_neg(self.eval_expr(operand, env))
        Not => js_not(self.eval_expr(operand, env))
        Plus => js_pos(self.eval_expr(operand, env))
        Typeof => js_typeof(self.eval_expr(operand, env))
        Void => {
          let _ = self.eval_expr(operand, env)
          Undefined
        }
      }
    Call(name, args) => {
      // 関数を環境から取得
      let func = env.get(name)
      let arg_values : Array[JSValue] = []
      for arg in args {
        arg_values.push(self.eval_expr(arg, env))
      }
      self.call_function(func, arg_values)
    }
    MethodCall(obj_expr, method_name, args) => {
      let obj = self.eval_expr(obj_expr, env)
      let arg_values : Array[JSValue] = []
      for arg in args {
        arg_values.push(self.eval_expr(arg, env))
      }
      self.call_method(obj, method_name, arg_values)
    }
    ArrayLit(elements) => {
      let items : Array[JSValue] = []
      for elem in elements {
        items.push(self.eval_expr(elem, env))
      }
      Array(items)
    }
    ObjectLit(fields) => {
      let props : Array[JSProp] = []
      for field in fields {
        let (key, val_expr) = field
        props.push({ key, value: self.eval_expr(val_expr, env) })
      }
      Object({ props, prototype: None })
    }
    IndexAccess(obj_expr, idx_expr) => {
      let obj = self.eval_expr(obj_expr, env)
      let idx = self.eval_expr(idx_expr, env)
      let key = idx.to_js_string()
      js_get_prop(obj, key)
    }
    PropAccess(obj_expr, prop) => {
      let obj = self.eval_expr(obj_expr, env)
      js_get_prop(obj, prop)
    }
    AssignExpr(name, val_expr) => {
      let val = self.eval_expr(val_expr, env)
      if not(env.set(name, val)) {
        // 変数が見つからない場合はグローバルに定義
        self.global_env.define(name, val)
      }
      val
    }
    Cond(cond, then_expr, else_expr) => {
      let cond_val = self.eval_expr(cond, env)
      if cond_val.to_boolean() {
        self.eval_expr(then_expr, env)
      } else {
        self.eval_expr(else_expr, env)
      }
    }
    New(class_name, args) => {
      let arg_values : Array[JSValue] = []
      for arg in args {
        arg_values.push(self.eval_expr(arg, env))
      }
      self.new_instance(class_name, arg_values)
    }
    ArrowFunc(params, body) => {
      let param_names : Array[String] = []
      for param in params {
        param_names.push(param.name)
      }
      JSValue::Function({
        params: param_names,
        body: match body {
          ArrowExpr(expr) =>
            Ast({
              name: "<arrow>",
              params,
              return_type: Any,
              body: { stmts: [Return(Some(expr))] },
            })
          ArrowBlock(block) =>
            Ast({ name: "<arrow>", params, return_type: Any, body: block })
        },
        env,
      })
    }
    FuncExpr(func) => {
      let param_names : Array[String] = []
      for param in func.params {
        param_names.push(param.name)
      }
      JSValue::Function({ params: param_names, body: Ast(func), env })
    }
  }
}

///|
/// 文を実行（戻り値はReturnの場合のみSome）
pub fn JSInterpreter::exec_stmt(
  self : JSInterpreter,
  stmt : TsStmt,
  env : JSEnv,
) -> JSValue? {
  self.tick()
  match self.take_error() {
    Some(err) => return Some(err)
    None => ()
  }
  match stmt {
    Let(name, _, init) | Const(name, _, init) => {
      let val = self.eval_expr(init, env)
      match self.take_error() {
        Some(err) => return Some(err)
        None => ()
      }
      env.define(name, val)
      None
    }
    Expr(expr) => {
      let _ = self.eval_expr(expr, env)
      match self.take_error() {
        Some(err) => Some(err)
        None => None
      }
    }
    Empty => None
    Block(block) => self.exec_block(block, env)
    Assign(name, val_expr) => {
      let val = self.eval_expr(val_expr, env)
      match self.take_error() {
        Some(err) => return Some(err)
        None => ()
      }
      let _ = env.set(name, val)
      None
    }
    Return(Some(expr)) => {
      let val = self.eval_expr(expr, env)
      match self.take_error() {
        Some(err) => Some(err)
        None => Some(val)
      }
    }
    Return(None) => Some(Undefined)
    If(cond, then_block, else_block) => {
      let cond_val = self.eval_expr(cond, env)
      match self.take_error() {
        Some(err) => return Some(err)
        None => ()
      }
      if cond_val.to_boolean() {
        self.exec_block(then_block, env)
      } else {
        match else_block {
          Some(block) => self.exec_block(block, env)
          None => None
        }
      }
    }
    While(cond, body) => {
      while self.eval_expr(cond, env).to_boolean() {
        match self.take_error() {
          Some(err) => return Some(err)
          None => ()
        }
        match self.exec_block(body, env) {
          Some(BreakSignal) => break
          Some(ContinueSignal) => continue
          Some(val) => return Some(val)
          None => ()
        }
      }
      None
    }
    For(init, cond, update, body) => {
      // 初期化
      match init {
        Some(init_stmt) => {
          match self.exec_stmt(init_stmt, env) {
            Some(val) => return Some(val)
            None => ()
          }

        }
        None => ()
      }
      // ループ
      while (match cond {
              Some(c) => self.eval_expr(c, env).to_boolean()
              None => true
            }) {
        match self.take_error() {
          Some(err) => return Some(err)
          None => ()
        }
        match self.exec_block(body, env) {
          Some(BreakSignal) => break
          Some(ContinueSignal) => {
            // 更新を実行してから次のイテレーションへ
            match update {
              Some(u) => {
                match self.exec_stmt(u, env) {
                  Some(val) => return Some(val)
                  None => ()
                }

              }
              None => ()
            }
            continue
          }
          Some(val) => return Some(val)
          None => ()
        }
        // 更新
        match update {
          Some(u) => {
            match self.exec_stmt(u, env) {
              Some(val) => return Some(val)
              None => ()
            }

          }
          None => ()
        }
      }
      None
    }
    Break => Some(BreakSignal)
    Continue => Some(ContinueSignal)
    CompoundAssign(name, op, val_expr) => {
      let current = env.get(name)
      let val = self.eval_expr(val_expr, env)
      match self.take_error() {
        Some(err) => return Some(err)
        None => ()
      }
      let new_val = match op {
        AddAssign => js_add(current, val)
        SubAssign => js_sub(current, val)
        MulAssign => js_mul(current, val)
        DivAssign => js_div(current, val)
      }
      let _ = env.set(name, new_val)
      None
    }
    IndexAssign(arr_expr, idx_expr, val_expr) => {
      let arr = self.eval_expr(arr_expr, env)
      let idx = self.eval_expr(idx_expr, env)
      let val = self.eval_expr(val_expr, env)
      match self.take_error() {
        Some(err) => return Some(err)
        None => ()
      }
      match arr {
        Array(items) => {
          let i = idx.to_number().to_int()
          if i >= 0 && i < items.length() {
            items[i] = val
          }
        }
        Object(map) => {
          let key = idx.to_js_string()
          let _ = js_set_prop(Object(map), key, val)

        }
        _ => ()
      }
      None
    }
    PropAssign(obj_expr, prop, val_expr) => {
      let obj = self.eval_expr(obj_expr, env)
      let val = self.eval_expr(val_expr, env)
      match self.take_error() {
        Some(err) => return Some(err)
        None => ()
      }
      let _ = js_set_prop(obj, prop, val)
      None
    }
    ForOf(var_name, _, iterable, body) => {
      let iter_val = self.eval_expr(iterable, env)
      match self.take_error() {
        Some(err) => return Some(err)
        None => ()
      }
      match iter_val {
        Array(items) => {
          let mut idx = 0
          while idx < items.length() {
            let item = items[idx]
            env.define(var_name, item)
            match self.exec_block(body, env) {
              Some(BreakSignal) => break
              Some(ContinueSignal) => {
                idx += 1
                continue
              }
              Some(val) => return Some(val)
              None => ()
            }
            idx += 1
          }
        }
        String(s) => {
          // 文字列のイテレーション
          let mut idx = 0
          while idx < s.length() {
            let char_str = try { s[idx:idx + 1].to_string() } catch { _ => "" }
            env.define(var_name, String(char_str))
            match self.exec_block(body, env) {
              Some(BreakSignal) => break
              Some(ContinueSignal) => {
                idx += 1
                continue
              }
              Some(val) => return Some(val)
              None => ()
            }
            idx += 1
          }
        }
        _ => () // イテレート不可
      }
      None
    }
  }
}

///|
/// ブロックを実行
pub fn JSInterpreter::exec_block(
  self : JSInterpreter,
  block : TsBlock,
  env : JSEnv,
) -> JSValue? {
  for stmt in block.stmts {
    match self.exec_stmt(stmt, env) {
      Some(val) => return Some(val)
      None => ()
    }
  }
  None
}

///|
/// 関数を呼び出す
pub fn JSInterpreter::call_function(
  self : JSInterpreter,
  func : JSValue,
  args : Array[JSValue],
) -> JSValue {
  match func {
    Function(closure) => {
      // 新しい環境を作成
      let call_env = js_new_env(Some(closure.env))

      // 引数をバインド
      for i, param in closure.params {
        let val = if i < args.length() { args[i] } else { Undefined }
        call_env.define(param, val)
      }

      // 本体を実行
      match closure.body {
        Ast(func_def) =>
          match self.exec_block(func_def.body, call_env) {
            Some(val) => val
            None => Undefined
          }
        Native(name) => self.call_native(name, args)
        Compiled(_) => Undefined // TODO
      }
    }
    Object(map) => {
      let callee = js_get_prop(Object(map), "$call")
      match callee {
        Function(_) => self.call_function(callee, args)
        _ => Undefined
      }
    }
    _ => Undefined
  }
}

///|
/// メソッドを呼び出す
pub fn JSInterpreter::call_method(
  self : JSInterpreter,
  obj : JSValue,
  method_name : String,
  args : Array[JSValue],
) -> JSValue {
  match obj {
    String(s) => self.string_method(s, method_name, args)
    Array(arr) => self.array_method(arr, method_name, args)
    Object(map) => {
      // オブジェクトのメソッドを検索
      let func = js_get_prop(Object(map), method_name)
      self.call_function(func, args)
    }
    _ => Undefined
  }
}

///|
/// 文字列メソッド
fn JSInterpreter::string_method(
  _self : JSInterpreter,
  s : String,
  method_name : String,
  args : Array[JSValue],
) -> JSValue {
  match method_name {
    "length" => Number(s.length().to_double())
    "charAt" => {
      let idx = if args.length() > 0 { args[0].to_number().to_int() } else { 0 }
      if idx >= 0 && idx < s.length() {
        String(try { s[idx:idx + 1].to_string() } catch { _ => "" })
      } else {
        String("")
      }
    }
    "indexOf" => {
      let search_str = if args.length() > 0 {
        args[0].to_js_string()
      } else {
        ""
      }
      let start_idx = if args.length() > 1 {
        args[1].to_number().to_int()
      } else {
        0
      }
      // 手動実装: s.index_of() は存在しないのでループで検索
      let mut idx = -1
      if start_idx < s.length() && search_str.length() > 0 {
        let search_len = search_str.length()
        let end_idx = s.length() - search_len + 1
        let mut i = start_idx
        while i < end_idx && idx == -1 {
          if (try { s[i:i + search_len].to_string() } catch { _ => "" }) == search_str {
            idx = i
          }
          i = i + 1
        }
      }
      Number(idx.to_double())
    }
    "split" => {
      let sep = if args.length() > 0 { args[0].to_js_string() } else { "" }
      let parts = s.split(sep)
      let result : Array[JSValue] = []
      for part in parts {
        result.push(String(part.to_string()))
      }
      JSValue::Array(result)
    }
    "replace" => {
      let from = if args.length() > 0 { args[0].to_js_string() } else { "" }
      let to = if args.length() > 1 { args[1].to_js_string() } else { "" }
      String(s.replace(old=from, new=to))
    }
    "trim" => {
      let trim_result = s.trim()
      String(trim_result.to_string())
    }
    "substring" => {
      let start = if args.length() > 0 {
        args[0].to_number().to_int()
      } else {
        0
      }
      let end = if args.length() > 1 {
        args[1].to_number().to_int()
      } else {
        s.length()
      }
      String(try { s[start:end].to_string() } catch { _ => "" })
    }
    "toUpperCase" => String(s.to_upper())
    "toLowerCase" => String(s.to_lower())
    "concat" => {
      let mut result = s
      for arg in args {
        result = result + arg.to_js_string()
      }
      String(result)
    }
    _ => Undefined
  }
}

///|
/// 配列メソッド
fn JSInterpreter::array_method(
  self : JSInterpreter,
  arr : Array[JSValue],
  method_name : String,
  args : Array[JSValue],
) -> JSValue {
  match method_name {
    "length" => JSValue::Number(arr.length().to_double())
    "push" => {
      for arg in args {
        arr.push(arg)
      }
      JSValue::Number(arr.length().to_double())
    }
    "pop" =>
      if arr.length() > 0 {
        arr.pop().unwrap_or(Undefined)
      } else {
        Undefined
      }
    "shift" =>
      if arr.length() > 0 {
        let first = arr[0]
        // Remove first element by creating new array
        let new_arr : Array[JSValue] = []
        for i in 1..<arr.length() {
          new_arr.push(arr[i])
        }
        arr.clear()
        for item in new_arr {
          arr.push(item)
        }
        first
      } else {
        Undefined
      }
    "join" => {
      let sep = if args.length() > 0 { args[0].to_js_string() } else { "," }
      let parts : Array[String] = []
      for item in arr {
        parts.push(item.to_js_string())
      }
      JSValue::String(parts.join(sep))
    }
    "indexOf" => {
      if args.length() > 0 {
        let target = args[0]
        for i, item in arr {
          match js_strict_eq(item, target) {
            JSValue::Bool(true) => return JSValue::Number(i.to_double())
            _ => ()
          }
        }
      }
      JSValue::Number(-1.0)
    }
    "includes" => {
      if args.length() > 0 {
        let target = args[0]
        for _, item in arr {
          match js_strict_eq(item, target) {
            Bool(true) => return JSValue::Bool(true)
            _ => ()
          }
        }
      }
      Bool(false)
    }
    "map" =>
      if args.length() > 0 {
        match args[0] {
          JSValue::Function(closure) => {
            let result : Array[JSValue] = []
            for i, item in arr {
              let args_array = [
                item,
                JSValue::Number(i.to_double()),
                JSValue::Array(arr),
              ]
              let mapped = self.call_function(
                JSValue::Function(closure),
                args_array,
              )
              result.push(mapped)
            }
            JSValue::Array(result)
          }
          _ => JSValue::Array([])
        }
      } else {
        JSValue::Array([])
      }
    "filter" =>
      if args.length() > 0 {
        match args[0] {
          JSValue::Function(closure) => {
            let result : Array[JSValue] = []
            for i, item in arr {
              let args_array = [
                item,
                JSValue::Number(i.to_double()),
                JSValue::Array(arr),
              ]
              let filtered = self.call_function(
                JSValue::Function(closure),
                args_array,
              )
              match filtered {
                Bool(true) => result.push(item)
                _ => ()
              }
            }
            JSValue::Array(result)
          }
          _ => JSValue::Array([])
        }
      } else {
        JSValue::Array([])
      }
    "reduce" =>
      if args.length() > 0 {
        match args[0] {
          JSValue::Function(closure) => {
            let initial_value = if args.length() > 1 {
              args[1]
            } else {
              Undefined
            }
            let mut accumulator = initial_value
            let mut start_index = 0
            let eq_result = js_strict_eq(initial_value, Undefined)
            let is_undefined = match eq_result {
              JSValue::Bool(true) => true
              JSValue::Bool(false) => false
              _ => false
            }
            if is_undefined && arr.length() > 0 {
              accumulator = arr[0]
              start_index = 1
            }
            for i in start_index..<arr.length() {
              let args_array = [
                accumulator,
                arr[i],
                JSValue::Number(i.to_double()),
                JSValue::Array(arr),
              ]
              accumulator = self.call_function(
                JSValue::Function(closure),
                args_array,
              )
            }
            accumulator
          }
          _ => Undefined
        }
      } else {
        Undefined
      }
    "forEach" =>
      if args.length() > 0 {
        match args[0] {
          JSValue::Function(closure) => {
            for i, item in arr {
              let args_array = [
                item,
                JSValue::Number(i.to_double()),
                JSValue::Array(arr),
              ]
              let _ = self.call_function(JSValue::Function(closure), args_array)

            }
            Undefined
          }
          _ => Undefined
        }
      } else {
        Undefined
      }
    "find" =>
      if args.length() > 0 {
        match args[0] {
          JSValue::Function(closure) => {
            for i, item in arr {
              let args_array = [
                item,
                JSValue::Number(i.to_double()),
                JSValue::Array(arr),
              ]
              let found = self.call_function(
                JSValue::Function(closure),
                args_array,
              )
              match found {
                Bool(true) => return item
                _ => ()
              }
            }
            Undefined
          }
          _ => Undefined
        }
      } else {
        Undefined
      }
    "slice" =>
      if args.length() > 0 {
        match args[0] {
          Array(arr) => {
            let mut start = if args.length() > 1 {
              match args[1] {
                JSValue::Number(n) => {
                  let si = n.to_int()
                  if si < 0 {
                    let len = arr.length()
                    if -si > len {
                      0
                    } else {
                      len + si
                    }
                  } else {
                    si
                  }
                }
                _ => 0
              }
            } else {
              0
            }
            let mut end = if args.length() > 2 {
              match args[2] {
                JSValue::Number(n) => {
                  let ei = n.to_int()
                  if ei < 0 {
                    let len = arr.length()
                    if -ei > len {
                      0
                    } else {
                      len + ei
                    }
                  } else {
                    ei
                  }
                }
                _ => arr.length()
              }
            } else {
              arr.length()
            }
            let len = arr.length()
            if start < 0 {
              start = 0
            }
            if end < 0 {
              end = 0
            }
            if start > len {
              start = len
            }
            if end > len {
              end = len
            }
            if start > end {
              let temp = start
              start = end
              end = temp
            }
            let result : Array[JSValue] = []
            for i in start..<end {
              result.push(arr[i])
            }
            JSValue::Array(result)
          }
          _ => JSValue::Array([])
        }
      } else {
        JSValue::Array([])
      }
    "concat" =>
      if args.length() > 0 {
        match args[0] {
          Array(arr) => {
            let result : Array[JSValue] = arr.copy()
            if args.length() > 1 {
              match args[1] {
                Array(other_arr) =>
                  for item in other_arr {
                    result.push(item)
                  }
                _ => result.push(args[1])
              }
            }
            JSValue::Array(result)
          }
          _ => JSValue::Array([])
        }
      } else {
        JSValue::Array([])
      }
    "unshift" =>
      if args.length() > 0 {
        match args[0] {
          Array(arr) => {
            let new_arr : Array[JSValue] = []
            for i in 1..<args.length() {
              new_arr.push(args[i])
            }
            for item in arr {
              new_arr.push(item)
            }
            arr.clear()
            for item in new_arr {
              arr.push(item)
            }
            JSValue::Number(new_arr.length().to_double())
          }
          _ => JSValue::Number(0)
        }
      } else {
        JSValue::Number(0)
      }
    _ => Undefined
  }
}

///|
fn JSInterpreter::call_native(
  self : JSInterpreter,
  name : String,
  args : Array[JSValue],
) -> JSValue {
  match name {
    "console.log" => {
      let parts : Array[String] = []
      for arg in args {
        parts.push(arg.to_js_string())
      }
      println(parts.join(" "))
      Undefined
    }
    "Math.floor" =>
      if args.length() > 0 {
        Number(args[0].to_number().floor())
      } else {
        Number(js_nan)
      }
    "Math.ceil" =>
      if args.length() > 0 {
        Number(args[0].to_number().ceil())
      } else {
        Number(js_nan)
      }
    "Math.abs" =>
      if args.length() > 0 {
        Number(args[0].to_number().abs())
      } else {
        Number(js_nan)
      }
    "Math.sqrt" =>
      if args.length() > 0 {
        Number(args[0].to_number().sqrt())
      } else {
        Number(js_nan)
      }
    "Math.min" =>
      if args.length() == 0 {
        Number(1.0e308) // Infinity
      } else if args.length() == 1 {
        args[0]
      } else {
        let mut min_val = args[0].to_number()
        for i in 1..<args.length() {
          let val = args[i].to_number()
          if val < min_val {
            min_val = val
          }
        }
        Number(min_val)
      }
    "Math.max" =>
      if args.length() == 0 {
        Number(-1.0e308) // -Infinity
      } else if args.length() == 1 {
        args[0]
      } else {
        let mut max_val = args[0].to_number()
        for i in 1..<args.length() {
          let val = args[i].to_number()
          if val > max_val {
            max_val = val
          }
        }
        Number(max_val)
      }
    "Math.round" =>
      if args.length() > 0 {
        Number(args[0].to_number().round())
      } else {
        Number(js_nan)
      }
    "Math.random" =>
      // TODO: 適切なランダム実装
      Number(0.5)
    // test262 harness functions
    "print" => {
      let parts : Array[String] = []
      for arg in args {
        parts.push(arg.to_js_string())
      }
      println(parts.join(" "))
      Undefined
    }
    "assert" =>
      if args.length() > 0 {
        let condition = args[0].to_boolean()
        if condition {
          Undefined
        } else {
          let msg = if args.length() > 1 {
            args[1].to_js_string()
          } else {
            "Assertion failed"
          }
          self.set_error(msg)
        }
      } else {
        Undefined
      }
    "assert.sameValue" =>
      if args.length() >= 2 {
        let actual = args[0]
        let expected = args[1]
        let result = assert_same_value(
          actual,
          expected,
          if args.length() > 2 { Some(args[2].to_js_string()) } else { None },
        )
        match result {
          Success => Undefined
          Failure(msg) => self.set_error(msg)
        }
      } else {
        Undefined
      }
    "assert.notSameValue" =>
      if args.length() >= 2 {
        let actual = args[0]
        let unexpected = args[1]
        let result = assert_not_same_value(
          actual,
          unexpected,
          if args.length() > 2 { Some(args[2].to_js_string()) } else { None },
        )
        match result {
          Success => Undefined
          Failure(msg) => self.set_error(msg)
        }
      } else {
        Undefined
      }
    "assert.compareArray" =>
      if args.length() >= 2 {
        let actual = args[0]
        let expected = args[1]
        let result = compare_array(
          actual,
          expected,
          if args.length() > 2 { Some(args[2].to_js_string()) } else { None },
        )
        match result {
          Success => Undefined
          Failure(msg) => self.set_error(msg)
        }
      } else {
        Undefined
      }
    "$DONOTEVALUATE" => {
      // This function should never be called in a passing test
      self.set_error("$DONOTEVALUATE was called")
    }
    "$ERROR" => {
      let msg = if args.length() > 0 {
        args[0].to_js_string()
      } else {
        "$ERROR"
      }
      self.set_error(msg)
    }
    "$DONE" =>
      if args.length() > 0 {
        let err = args[0]
        if !err.is_undefined() {
          self.set_error("Async test failed: " + err.to_js_string())
        } else {
          Undefined
        }
      } else {
        Undefined
      }
    "$262.evalScript" =>
      if args.length() > 0 {
        let code = args[0].to_js_string()
        self.run(code) catch {
          _ => {
            let wrapped = "function main() {\n" + code + "\n}"
            self.run(wrapped) catch {
              e2 => {
                let _ = self.set_error("$262.evalScript parse error: \{e2}")
                Undefined
              }
            }
          }
        }
      } else {
        Undefined
      }
    _ => Undefined
  }
}

///|
/// newでインスタンスを作成
fn JSInterpreter::new_instance(
  self : JSInterpreter,
  class_name : String,
  args : Array[JSValue],
) -> JSValue {
  match class_name {
    "Test262Error" => {
      let msg = if args.length() > 0 {
        args[0].to_js_string()
      } else {
        ""
      }
      let obj = js_new_object()
      let _ = js_set_prop(obj, "name", JSValue::String("Test262Error"))
      let _ = js_set_prop(obj, "message", JSValue::String(msg))
      obj
    }
    "Array" =>
      if args.length() == 1 {
        match args[0] {
          Number(n) => {
            let len = n.to_int()
            let arr : Array[JSValue] = []
            for _ in 0..<len {
              arr.push(Undefined)
            }
            JSValue::Array(arr)
          }
          _ => JSValue::Array(args.copy())
        }
      } else {
        JSValue::Array(args.copy())
      }
    "Object" => js_new_object()
    _ => {
      // カスタムクラスのコンストラクタを検索
      let ctor = self.global_env.get(class_name)
      match ctor {
        Function(_) => {
          let instance = js_new_object()
          // TODO: thisをバインドしてコンストラクタを呼ぶ
          instance
        }
        _ => js_new_object()
      }
    }
  }
}

///|
/// モジュールを実行
pub fn JSInterpreter::run_module(
  self : JSInterpreter,
  module_ : TsModule,
) -> JSValue {
  // 関数を登録
  for func in module_.funcs {
    let param_names : Array[String] = []
    for param in func.params {
      param_names.push(param.name)
    }
    let closure = JSValue::Function({
      params: param_names,
      body: Ast(func),
      env: self.global_env,
    })
    self.global_env.define(func.name, closure)
  }

  // main関数があれば実行
  let main_func = self.global_env.get("main")
  match main_func {
    Function(_) => self.call_function(main_func, [])
    _ => Undefined
  }
}

///|
/// ソースコードを直接実行
pub fn JSInterpreter::run(
  self : JSInterpreter,
  source : String,
) -> JSValue raise ParseError {
  let parser = Parser::from_source(source)
  let module_ = parser.parse_module()
  self.run_module(module_)
}
