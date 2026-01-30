// AST traversal pass for collecting symbol usage information.

///|
/// Run usage analysis on a module.
pub fn analyze_usage(module_ : @ast.TsModule, source : String) -> SymbolTable {
  let table = SymbolTable::new(source)

  // Declare all top-level functions first
  for func in module_.funcs {
    table.add_symbol(func.name, Function, @ast.TsType::Any, 0)
  }

  // Analyze each function
  for func in module_.funcs {
    analyze_func_usage(table, func)
  }

  // Compute drop points
  table.compute_drop_points()
  table
}

///|
/// Analyze usage in a function.
fn analyze_func_usage(table : SymbolTable, func : @ast.TsFunc) -> Unit {
  table.enter_scope()

  // Declare parameters
  for param in func.params {
    match param.binding {
      Some(binding) => declare_binding_usage(table, binding, Param, param.type_)
      None => table.add_symbol(param.name, Param, param.type_, 0)
    }
  }

  // Analyze body
  analyze_block_usage(table, func.body)
  table.leave_scope()
}

///|
/// Declare bindings from a pattern.
fn declare_binding_usage(
  table : SymbolTable,
  binding : @ast.TsBinding,
  kind : DeclKind,
  type_ : @ast.TsType,
) -> Unit {
  match binding {
    @ast.TsBinding::Ident(name) => table.add_symbol(name, kind, type_, 0)
    @ast.TsBinding::Array(arr) => {
      for item in arr.items {
        match item {
          Some(elem) =>
            declare_binding_usage(table, elem.binding, kind, @ast.TsType::Any)
          None => ()
        }
      }
      match arr.rest {
        Some(rest) => declare_binding_usage(table, rest, kind, @ast.TsType::Any)
        None => ()
      }
    }
    @ast.TsBinding::Object(obj) => {
      for prop in obj.props {
        declare_binding_usage(table, prop.binding, kind, @ast.TsType::Any)
      }
      match obj.rest {
        Some(name) => table.add_symbol(name, kind, @ast.TsType::Any, 0)
        None => ()
      }
    }
    @ast.TsBinding::Target(_) => ()
  }
}

///|
/// Analyze usage in a block.
fn analyze_block_usage(table : SymbolTable, block : @ast.TsBlock) -> Unit {
  for stmt in block.stmts {
    analyze_stmt_usage(table, stmt)
  }
}

///|
/// Analyze usage in a statement.
fn analyze_stmt_usage(table : SymbolTable, stmt : @ast.TsStmt) -> Unit {
  match stmt {
    @ast.TsStmt::Var(binding, type_, init) => {
      // Analyze init first (before declaring)
      analyze_expr_usage(table, init)
      declare_binding_usage(table, binding, Var, type_)
    }
    @ast.TsStmt::Let(binding, type_, init) => {
      analyze_expr_usage(table, init)
      declare_binding_usage(table, binding, Let, type_)
    }
    @ast.TsStmt::Const(binding, type_, init) => {
      analyze_expr_usage(table, init)
      declare_binding_usage(table, binding, Const, type_)
    }
    @ast.TsStmt::Assign(name, expr) => {
      analyze_expr_usage(table, expr)
      table.record_use(name, Write, 0)
    }
    @ast.TsStmt::CompoundAssign(name, _, expr) => {
      analyze_expr_usage(table, expr)
      table.record_use(name, ReadWrite, 0)
    }
    @ast.TsStmt::IndexAssign(arr, idx, val) => {
      analyze_expr_usage(table, arr)
      analyze_expr_usage(table, idx)
      analyze_expr_usage(table, val)
    }
    @ast.TsStmt::PropAssign(obj, _, val) => {
      analyze_expr_usage(table, obj)
      analyze_expr_usage(table, val)
    }
    @ast.TsStmt::Expr(expr) => analyze_expr_usage(table, expr)
    @ast.TsStmt::Return(expr) =>
      match expr {
        Some(e) => {
          analyze_expr_usage(table, e)
          // Mark returned variables as escaped
          mark_expr_escaped(table, e)
        }
        None => ()
      }
    @ast.TsStmt::Throw(expr) => analyze_expr_usage(table, expr)
    @ast.TsStmt::If(cond, then_block, else_block) => {
      analyze_expr_usage(table, cond)
      table.enter_scope()
      analyze_block_usage(table, then_block)
      table.leave_scope()
      match else_block {
        Some(eb) => {
          table.enter_scope()
          analyze_block_usage(table, eb)
          table.leave_scope()
        }
        None => ()
      }
    }
    @ast.TsStmt::While(cond, body) => {
      analyze_expr_usage(table, cond)
      table.enter_scope()
      analyze_block_usage(table, body)
      table.leave_scope()
    }
    @ast.TsStmt::DoWhile(cond, body) => {
      table.enter_scope()
      analyze_block_usage(table, body)
      table.leave_scope()
      analyze_expr_usage(table, cond)
    }
    @ast.TsStmt::For(init, cond, update, body) => {
      table.enter_scope()
      match init {
        Some(s) => analyze_stmt_usage(table, s)
        None => ()
      }
      match cond {
        Some(e) => analyze_expr_usage(table, e)
        None => ()
      }
      match update {
        Some(s) => analyze_stmt_usage(table, s)
        None => ()
      }
      table.enter_scope()
      analyze_block_usage(table, body)
      table.leave_scope()
      table.leave_scope()
    }
    @ast.TsStmt::ForOf(kind, binding, type_, iterable, body) => {
      analyze_expr_usage(table, iterable)
      table.enter_scope()
      let decl_kind = for_of_kind_to_decl_kind(kind)
      declare_binding_usage(table, binding, decl_kind, type_)
      table.enter_scope()
      analyze_block_usage(table, body)
      table.leave_scope()
      table.leave_scope()
    }
    @ast.TsStmt::ForAwaitOf(kind, binding, type_, iterable, body) => {
      analyze_expr_usage(table, iterable)
      table.enter_scope()
      let decl_kind = for_of_kind_to_decl_kind(kind)
      declare_binding_usage(table, binding, decl_kind, type_)
      table.enter_scope()
      analyze_block_usage(table, body)
      table.leave_scope()
      table.leave_scope()
    }
    @ast.TsStmt::ForIn(kind, binding, type_, obj, body) => {
      analyze_expr_usage(table, obj)
      table.enter_scope()
      let decl_kind = for_of_kind_to_decl_kind(kind)
      declare_binding_usage(table, binding, decl_kind, type_)
      table.enter_scope()
      analyze_block_usage(table, body)
      table.leave_scope()
      table.leave_scope()
    }
    @ast.TsStmt::Switch(expr, cases) => {
      analyze_expr_usage(table, expr)
      table.enter_scope()
      for case_ in cases {
        match case_.test_expr {
          Some(e) => analyze_expr_usage(table, e)
          None => ()
        }
        analyze_block_usage(table, case_.body)
      }
      table.leave_scope()
    }
    @ast.TsStmt::Try(try_block, catch_binding, catch_block, finally_block) => {
      table.enter_scope()
      analyze_block_usage(table, try_block)
      table.leave_scope()
      match (catch_binding, catch_block) {
        (Some(binding), Some(cb)) => {
          table.enter_scope()
          declare_binding_usage(table, binding, CatchParam, @ast.TsType::Any)
          analyze_block_usage(table, cb)
          table.leave_scope()
        }
        (None, Some(cb)) => {
          table.enter_scope()
          analyze_block_usage(table, cb)
          table.leave_scope()
        }
        _ => ()
      }
      match finally_block {
        Some(fb) => {
          table.enter_scope()
          analyze_block_usage(table, fb)
          table.leave_scope()
        }
        None => ()
      }
    }
    @ast.TsStmt::With(expr, body) => {
      analyze_expr_usage(table, expr)
      table.enter_scope()
      analyze_block_usage(table, body)
      table.leave_scope()
    }
    @ast.TsStmt::Block(inner) => {
      table.enter_scope()
      analyze_block_usage(table, inner)
      table.leave_scope()
    }
    @ast.TsStmt::Label(_, inner) => analyze_stmt_usage(table, inner)
    @ast.TsStmt::Break(_) | @ast.TsStmt::Continue(_) => ()
    @ast.TsStmt::Empty | @ast.TsStmt::Debugger => ()
  }
}

///|
fn for_of_kind_to_decl_kind(kind : @ast.TsForOfKind) -> DeclKind {
  match kind {
    @ast.TsForOfKind::Let => Let
    @ast.TsForOfKind::Const => Const
    @ast.TsForOfKind::Var => Var
    @ast.TsForOfKind::Assign => Var
  }
}

///|
/// Analyze usage in an expression.
fn analyze_expr_usage(table : SymbolTable, expr : @ast.TsExpr) -> Unit {
  match expr {
    @ast.TsExpr::Var(name) => table.record_use(name, Read, 0)
    @ast.TsExpr::BinOp(_, left, right) => {
      analyze_expr_usage(table, left)
      analyze_expr_usage(table, right)
    }
    @ast.TsExpr::UnaryOp(op, operand) =>
      match op {
        @ast.TsUnaryOp::PreInc
        | @ast.TsUnaryOp::PreDec
        | @ast.TsUnaryOp::PostInc
        | @ast.TsUnaryOp::PostDec =>
          // These modify the operand
          analyze_expr_as_lvalue(table, operand)
        _ => analyze_expr_usage(table, operand)
      }
    @ast.TsExpr::Call(name, args) => {
      table.record_use(name, Read, 0)
      for arg in args {
        analyze_expr_usage(table, arg)
        // Arguments passed to functions are potentially escaped
        mark_expr_escaped(table, arg)
      }
    }
    @ast.TsExpr::CallExpr(callee, args) => {
      analyze_expr_usage(table, callee)
      for arg in args {
        analyze_expr_usage(table, arg)
        mark_expr_escaped(table, arg)
      }
    }
    @ast.TsExpr::Cond(cond, then_, else_) => {
      analyze_expr_usage(table, cond)
      analyze_expr_usage(table, then_)
      analyze_expr_usage(table, else_)
    }
    @ast.TsExpr::ArrayLit(elements) =>
      for elem in elements {
        analyze_expr_usage(table, elem)
      }
    @ast.TsExpr::Spread(inner) => analyze_expr_usage(table, inner)
    @ast.TsExpr::ObjectLit(fields) =>
      for field in fields {
        let (_, value) = field
        analyze_expr_usage(table, value)
      }
    @ast.TsExpr::ComputedProp(key, value) => {
      analyze_expr_usage(table, key)
      analyze_expr_usage(table, value)
    }
    @ast.TsExpr::IndexAccess(arr, idx) => {
      analyze_expr_usage(table, arr)
      analyze_expr_usage(table, idx)
    }
    @ast.TsExpr::PropAccess(obj, _) => analyze_expr_usage(table, obj)
    @ast.TsExpr::New(_, args) =>
      for arg in args {
        analyze_expr_usage(table, arg)
        mark_expr_escaped(table, arg)
      }
    @ast.TsExpr::NewExpr(ctor, args) => {
      analyze_expr_usage(table, ctor)
      for arg in args {
        analyze_expr_usage(table, arg)
        mark_expr_escaped(table, arg)
      }
    }
    @ast.TsExpr::MethodCall(receiver, _, args) => {
      analyze_expr_usage(table, receiver)
      for arg in args {
        analyze_expr_usage(table, arg)
        mark_expr_escaped(table, arg)
      }
    }
    @ast.TsExpr::AssignExpr(name, value) => {
      analyze_expr_usage(table, value)
      table.record_use(name, Write, 0)
    }
    @ast.TsExpr::AssignPattern(_, value) => analyze_expr_usage(table, value)
    @ast.TsExpr::CompoundAssignExpr(target, _, value) => {
      analyze_expr_usage(table, value)
      analyze_expr_as_lvalue(table, target)
    }
    @ast.TsExpr::PropAssignExpr(obj, _, value) => {
      analyze_expr_usage(table, obj)
      analyze_expr_usage(table, value)
    }
    @ast.TsExpr::IndexAssignExpr(obj, idx, value) => {
      analyze_expr_usage(table, obj)
      analyze_expr_usage(table, idx)
      analyze_expr_usage(table, value)
    }
    @ast.TsExpr::Seq(left, right) => {
      analyze_expr_usage(table, left)
      analyze_expr_usage(table, right)
    }
    @ast.TsExpr::ArrowFunc(params, body, _) => {
      // Enter closure context - captures from outer scope
      table.enter_closure()
      for param in params {
        match param.binding {
          Some(binding) =>
            declare_binding_usage(table, binding, Param, param.type_)
          None => table.add_symbol(param.name, Param, param.type_, 0)
        }
        match param.default {
          Some(def) => analyze_expr_usage(table, def)
          None => ()
        }
      }
      match body {
        @ast.TsArrowBody::ArrowExpr(e) => analyze_expr_usage(table, e)
        @ast.TsArrowBody::ArrowBlock(b) => analyze_block_usage(table, b)
      }
      table.leave_closure()
    }
    @ast.TsExpr::FuncExpr(func) => {
      // Named function expression creates binding in its own scope
      table.enter_closure()
      if func.name != "<anon>" {
        table.add_symbol(func.name, Function, @ast.TsType::Any, 0)
      }
      for param in func.params {
        match param.binding {
          Some(binding) =>
            declare_binding_usage(table, binding, Param, param.type_)
          None => table.add_symbol(param.name, Param, param.type_, 0)
        }
      }
      analyze_block_usage(table, func.body)
      table.leave_closure()
    }
    @ast.TsExpr::Yield(inner) =>
      match inner {
        Some(e) => analyze_expr_usage(table, e)
        None => ()
      }
    @ast.TsExpr::YieldStar(inner) => analyze_expr_usage(table, inner)
    @ast.TsExpr::Await(inner) => analyze_expr_usage(table, inner)
    @ast.TsExpr::DynamicImport(spec) => analyze_expr_usage(table, spec)
    @ast.TsExpr::TemplateLiteral(_, exprs) =>
      for e in exprs {
        analyze_expr_usage(table, e)
      }
    @ast.TsExpr::TaggedTemplate(tag, _, _, exprs) => {
      analyze_expr_usage(table, tag)
      for e in exprs {
        analyze_expr_usage(table, e)
      }
    }
    // Literals don't have usage
    @ast.TsExpr::NumberLit(_)
    | @ast.TsExpr::IntLit(_)
    | @ast.TsExpr::BigIntLit(_)
    | @ast.TsExpr::BoolLit(_)
    | @ast.TsExpr::StringLit(_)
    | @ast.TsExpr::NullLit
    | @ast.TsExpr::ArrayHole
    | @ast.TsExpr::ImportMeta => ()
  }
}

///|
/// Analyze expression as lvalue (assignment target).
fn analyze_expr_as_lvalue(table : SymbolTable, expr : @ast.TsExpr) -> Unit {
  match expr {
    @ast.TsExpr::Var(name) => table.record_use(name, ReadWrite, 0)
    @ast.TsExpr::PropAccess(obj, _) => analyze_expr_usage(table, obj)
    @ast.TsExpr::IndexAccess(arr, idx) => {
      analyze_expr_usage(table, arr)
      analyze_expr_usage(table, idx)
    }
    _ => analyze_expr_usage(table, expr)
  }
}

///|
/// Mark variables in expression as escaped.
fn mark_expr_escaped(table : SymbolTable, expr : @ast.TsExpr) -> Unit {
  match expr {
    @ast.TsExpr::Var(name) => table.mark_escaped(name)
    @ast.TsExpr::ArrayLit(elements) =>
      for elem in elements {
        mark_expr_escaped(table, elem)
      }
    @ast.TsExpr::ObjectLit(fields) =>
      for field in fields {
        mark_expr_escaped(table, field.1)
      }
    @ast.TsExpr::Spread(inner) => mark_expr_escaped(table, inner)
    _ => ()
  }
}

///|
/// Analyze a block and return usage information.
pub fn analyze_block_usage_standalone(
  block : @ast.TsBlock,
  source : String,
) -> SymbolTable {
  let table = SymbolTable::new(source)
  analyze_block_usage(table, block)
  table.compute_drop_points()
  table
}
