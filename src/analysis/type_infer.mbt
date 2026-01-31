// Type inference pass for producing TypedModule.

///|
/// Type inference context with scope and type information.
pub(all) struct TypeInferCtx {
  analysis_ctx : AnalysisCtx
  // Variable types in current scope
  var_types : Map[String, @ast.TsType]
  // Function return types
  func_return_types : Map[String, @ast.TsType]
  // Current function's expected return type
  mut expected_return : @ast.TsType
}

///|
/// Create a new type inference context.
pub fn TypeInferCtx::new(source : String) -> TypeInferCtx {
  {
    analysis_ctx: AnalysisCtx::new(source),
    var_types: {},
    func_return_types: {},
    expected_return: @ast.TsType::Any,
  }
}

///|
/// Add variable type to context.
pub fn TypeInferCtx::add_var(
  self : TypeInferCtx,
  name : String,
  type_ : @ast.TsType,
) -> Unit {
  self.var_types[name] = type_
}

///|
/// Get variable type from context.
pub fn TypeInferCtx::get_var_type(
  self : TypeInferCtx,
  name : String,
) -> @ast.TsType {
  match self.var_types.get(name) {
    Some(t) => t
    None => @ast.TsType::Any
  }
}

///|
/// Infer literal type from expression.
pub fn infer_literal_type(expr : @ast.TsExpr) -> @ast.TsType {
  match expr {
    @ast.TsExpr::IntLit(_) => @ast.TsType::Int
    @ast.TsExpr::NumberLit(_) => @ast.TsType::Number
    @ast.TsExpr::BigIntLit(_) => @ast.TsType::Any
    @ast.TsExpr::BoolLit(_) => @ast.TsType::Boolean
    @ast.TsExpr::StringLit(_) => @ast.TsType::String_
    @ast.TsExpr::NullLit => @ast.TsType::Any
    @ast.TsExpr::ArrayHole => @ast.TsType::Any
    @ast.TsExpr::ArrayLit(_) => @ast.TsType::Any
    @ast.TsExpr::Spread(_) => @ast.TsType::Any
    @ast.TsExpr::ComputedProp(_, _) => @ast.TsType::Any
    @ast.TsExpr::ObjectLit(_) => @ast.TsType::Any
    @ast.TsExpr::Var(_) => @ast.TsType::Any
    @ast.TsExpr::Yield(_) => @ast.TsType::Any
    @ast.TsExpr::YieldStar(_) => @ast.TsType::Any
    @ast.TsExpr::Await(_) => @ast.TsType::Any
    @ast.TsExpr::DynamicImport(_) => @ast.TsType::Any
    @ast.TsExpr::ImportMeta => @ast.TsType::Any
    @ast.TsExpr::TemplateLiteral(_, _) => @ast.TsType::String_
    @ast.TsExpr::TaggedTemplate(_, _, _, _) => @ast.TsType::Any
    @ast.TsExpr::Seq(_, right) => infer_literal_type(right)
    @ast.TsExpr::PropAssignExpr(_, _, value) => infer_literal_type(value)
    @ast.TsExpr::IndexAssignExpr(_, _, value) => infer_literal_type(value)
    @ast.TsExpr::CompoundAssignExpr(left, _, _) => infer_literal_type(left)
    @ast.TsExpr::BinOp(op, lhs, _) =>
      match op {
        @ast.TsBinOp::BinEq
        | @ast.TsBinOp::BinNe
        | @ast.TsBinOp::AbstractEq
        | @ast.TsBinOp::AbstractNe
        | @ast.TsBinOp::BinLt
        | @ast.TsBinOp::BinLe
        | @ast.TsBinOp::BinGt
        | @ast.TsBinOp::BinGe
        | @ast.TsBinOp::Instanceof
        | @ast.TsBinOp::In
        | @ast.TsBinOp::And
        | @ast.TsBinOp::Or
        | @ast.TsBinOp::Coalesce => @ast.TsType::Boolean
        @ast.TsBinOp::Add
        | @ast.TsBinOp::Sub
        | @ast.TsBinOp::Mul
        | @ast.TsBinOp::Div
        | @ast.TsBinOp::Mod
        | @ast.TsBinOp::Pow
        | @ast.TsBinOp::BitAnd
        | @ast.TsBinOp::BitOr
        | @ast.TsBinOp::BitXor
        | @ast.TsBinOp::Shl
        | @ast.TsBinOp::Shr
        | @ast.TsBinOp::UShr => infer_literal_type(lhs)
      }
    @ast.TsExpr::UnaryOp(op, e) =>
      match op {
        @ast.TsUnaryOp::Neg | @ast.TsUnaryOp::Plus => infer_literal_type(e)
        @ast.TsUnaryOp::Not => @ast.TsType::Boolean
        @ast.TsUnaryOp::BitwiseNot => @ast.TsType::Number
        @ast.TsUnaryOp::Typeof => @ast.TsType::String_
        @ast.TsUnaryOp::Void => @ast.TsType::Any
        @ast.TsUnaryOp::Delete => @ast.TsType::Boolean
        @ast.TsUnaryOp::PreInc
        | @ast.TsUnaryOp::PreDec
        | @ast.TsUnaryOp::PostInc
        | @ast.TsUnaryOp::PostDec => infer_literal_type(e)
      }
    @ast.TsExpr::Call(_, _) => @ast.TsType::Any
    @ast.TsExpr::CallExpr(_, _) => @ast.TsType::Any
    @ast.TsExpr::Cond(_, then_, _) => infer_literal_type(then_)
    @ast.TsExpr::IndexAccess(_, _) => @ast.TsType::Any
    @ast.TsExpr::PropAccess(_, prop) =>
      if prop == "length" {
        @ast.TsType::Int
      } else {
        @ast.TsType::Any
      }
    @ast.TsExpr::New(_, _) => @ast.TsType::Any
    @ast.TsExpr::NewExpr(_, _) => @ast.TsType::Any
    @ast.TsExpr::MethodCall(_, _, _) => @ast.TsType::Any
    @ast.TsExpr::AssignExpr(_, e) => infer_literal_type(e)
    @ast.TsExpr::AssignPattern(_, e) => infer_literal_type(e)
    @ast.TsExpr::ArrowFunc(_, _, _) => @ast.TsType::Any
    @ast.TsExpr::FuncExpr(_) => @ast.TsType::Any
  }
}

///|
/// Resolve Any type from declared type and initializer (without context).
pub fn resolve_any(declared : @ast.TsType, init : @ast.TsExpr) -> @ast.TsType {
  match declared {
    @ast.TsType::Any => infer_literal_type(init)
    _ => declared
  }
}

///|
/// Resolve Any type using context for better inference.
/// Uses infer_expr_type to track variable types through expressions.
pub fn resolve_any_with_ctx(
  ctx : TypeInferCtx,
  declared : @ast.TsType,
  init : @ast.TsExpr,
) -> @ast.TsType {
  match declared {
    @ast.TsType::Any => infer_expr_type(ctx, init)
    _ => declared
  }
}

///|
/// Infer expression type with context.
pub fn infer_expr_type(ctx : TypeInferCtx, expr : @ast.TsExpr) -> @ast.TsType {
  match expr {
    @ast.TsExpr::NumberLit(_) => @ast.TsType::Number
    @ast.TsExpr::IntLit(_) => @ast.TsType::Int
    @ast.TsExpr::BigIntLit(_) => @ast.TsType::Any
    @ast.TsExpr::BoolLit(_) => @ast.TsType::Boolean
    @ast.TsExpr::StringLit(_) => @ast.TsType::String_
    @ast.TsExpr::NullLit => @ast.TsType::Any
    @ast.TsExpr::ArrayHole => @ast.TsType::Any
    @ast.TsExpr::Spread(_) => @ast.TsType::Any
    @ast.TsExpr::ComputedProp(_, _) => @ast.TsType::Any
    @ast.TsExpr::ObjectLit(_) => @ast.TsType::Any
    @ast.TsExpr::Seq(_, right) => infer_expr_type(ctx, right)
    @ast.TsExpr::PropAssignExpr(_, _, value) => infer_expr_type(ctx, value)
    @ast.TsExpr::IndexAssignExpr(_, _, value) => infer_expr_type(ctx, value)
    @ast.TsExpr::CompoundAssignExpr(left, _, _) => infer_expr_type(ctx, left)
    @ast.TsExpr::Yield(_) => @ast.TsType::Any
    @ast.TsExpr::YieldStar(_) => @ast.TsType::Any
    @ast.TsExpr::Await(_) => @ast.TsType::Any
    @ast.TsExpr::DynamicImport(_) => @ast.TsType::Any
    @ast.TsExpr::ImportMeta => @ast.TsType::Any
    @ast.TsExpr::TemplateLiteral(_, _) => @ast.TsType::String_
    @ast.TsExpr::TaggedTemplate(_, _, _, _) => @ast.TsType::Any
    @ast.TsExpr::Var(name) => ctx.get_var_type(name)
    @ast.TsExpr::BinOp(op, left, right) =>
      infer_binop_type(ctx, op, left, right)
    @ast.TsExpr::UnaryOp(op, operand) =>
      match op {
        @ast.TsUnaryOp::Neg | @ast.TsUnaryOp::Plus =>
          infer_expr_type(ctx, operand)
        @ast.TsUnaryOp::Not => @ast.TsType::Boolean
        @ast.TsUnaryOp::BitwiseNot => @ast.TsType::Number
        @ast.TsUnaryOp::Typeof => @ast.TsType::String_
        @ast.TsUnaryOp::Void => @ast.TsType::Any
        @ast.TsUnaryOp::Delete => @ast.TsType::Boolean
        @ast.TsUnaryOp::PreInc
        | @ast.TsUnaryOp::PreDec
        | @ast.TsUnaryOp::PostInc
        | @ast.TsUnaryOp::PostDec => infer_expr_type(ctx, operand)
      }
    @ast.TsExpr::Call(name, _) =>
      match ctx.func_return_types.get(name) {
        Some(t) => t
        None => @ast.TsType::Any
      }
    @ast.TsExpr::CallExpr(_, _) => @ast.TsType::Any
    @ast.TsExpr::Cond(_, then_expr, _) => infer_expr_type(ctx, then_expr)
    @ast.TsExpr::ArrayLit(elements) =>
      if elements.length() > 0 {
        @ast.TsType::Array(infer_expr_type(ctx, elements[0]))
      } else {
        @ast.TsType::Array(@ast.TsType::Number)
      }
    @ast.TsExpr::IndexAccess(arr, _) =>
      match infer_expr_type(ctx, arr) {
        @ast.TsType::Array(elem_type) => elem_type
        _ => @ast.TsType::Any
      }
    @ast.TsExpr::PropAccess(_, prop) =>
      if prop == "length" {
        @ast.TsType::Int
      } else {
        @ast.TsType::Any
      }
    @ast.TsExpr::New(_, _) => @ast.TsType::Any
    @ast.TsExpr::NewExpr(_, _) => @ast.TsType::Any
    @ast.TsExpr::MethodCall(receiver, method_name, _) =>
      infer_method_return_type(ctx, receiver, method_name)
    @ast.TsExpr::AssignExpr(_, e) => infer_expr_type(ctx, e)
    @ast.TsExpr::AssignPattern(_, e) => infer_expr_type(ctx, e)
    @ast.TsExpr::ArrowFunc(_, _, _) => @ast.TsType::Any
    @ast.TsExpr::FuncExpr(_) => @ast.TsType::Any
  }
}

///|
/// Infer binary operation result type.
pub fn infer_binop_type(
  ctx : TypeInferCtx,
  op : @ast.TsBinOp,
  left : @ast.TsExpr,
  right : @ast.TsExpr,
) -> @ast.TsType {
  match op {
    // Comparison operators always return Boolean
    @ast.TsBinOp::BinLt
    | @ast.TsBinOp::BinLe
    | @ast.TsBinOp::BinGt
    | @ast.TsBinOp::BinGe
    | @ast.TsBinOp::BinEq
    | @ast.TsBinOp::BinNe
    | @ast.TsBinOp::AbstractEq
    | @ast.TsBinOp::AbstractNe
    | @ast.TsBinOp::Instanceof
    | @ast.TsBinOp::In => @ast.TsType::Boolean
    // Logical operators: And returns left if falsy, else right. Or returns left if truthy, else right.
    @ast.TsBinOp::And | @ast.TsBinOp::Or => {
      let left_t = infer_expr_type(ctx, left)
      let right_t = infer_expr_type(ctx, right)
      unify_types(left_t, right_t)
    }
    // Nullish coalescing returns right type if left is nullable
    @ast.TsBinOp::Coalesce => {
      let left_t = infer_expr_type(ctx, left)
      let right_t = infer_expr_type(ctx, right)
      match left_t {
        @ast.TsType::Any | @ast.TsType::Null | @ast.TsType::Undefined => right_t
        _ => unify_types(left_t, right_t)
      }
    }
    // Bitwise operators always return Int
    @ast.TsBinOp::BitAnd
    | @ast.TsBinOp::BitOr
    | @ast.TsBinOp::BitXor
    | @ast.TsBinOp::Shl
    | @ast.TsBinOp::Shr
    | @ast.TsBinOp::UShr => @ast.TsType::Int
    // Add: string if either operand is string
    @ast.TsBinOp::Add => {
      let left_t = infer_expr_type(ctx, left)
      let right_t = infer_expr_type(ctx, right)
      if left_t == @ast.TsType::String_ || right_t == @ast.TsType::String_ {
        @ast.TsType::String_
      } else {
        unify_numeric_types(left_t, right_t)
      }
    }
    // Other arithmetic operators: promote to wider numeric type
    @ast.TsBinOp::Sub
    | @ast.TsBinOp::Mul
    | @ast.TsBinOp::Div
    | @ast.TsBinOp::Mod
    | @ast.TsBinOp::Pow => {
      let left_t = infer_expr_type(ctx, left)
      let right_t = infer_expr_type(ctx, right)
      unify_numeric_types(left_t, right_t)
    }
  }
}

///|
/// Unify two types, preferring the more specific one.
fn unify_types(t1 : @ast.TsType, t2 : @ast.TsType) -> @ast.TsType {
  if t1 == t2 {
    return t1
  }
  match (t1, t2) {
    (@ast.TsType::Any, t) => t
    (t, @ast.TsType::Any) => t
    (@ast.TsType::Number, @ast.TsType::Int) => @ast.TsType::Number
    (@ast.TsType::Int, @ast.TsType::Number) => @ast.TsType::Number
    _ => t1
  }
}

///|
/// Unify numeric types, preferring Number over Int.
fn unify_numeric_types(t1 : @ast.TsType, t2 : @ast.TsType) -> @ast.TsType {
  match (t1, t2) {
    (@ast.TsType::Number, _) => @ast.TsType::Number
    (_, @ast.TsType::Number) => @ast.TsType::Number
    (@ast.TsType::Int, _) => @ast.TsType::Int
    (_, @ast.TsType::Int) => @ast.TsType::Int
    (@ast.TsType::Any, t) => t
    (t, @ast.TsType::Any) => t
    _ => t1
  }
}

///|
/// Infer method call return type.
pub fn infer_method_return_type(
  ctx : TypeInferCtx,
  receiver : @ast.TsExpr,
  method_name : String,
) -> @ast.TsType {
  let recv_type = infer_expr_type(ctx, receiver)
  match recv_type {
    @ast.TsType::String_ =>
      match method_name {
        "charAt" => @ast.TsType::String_
        "charCodeAt" => @ast.TsType::Int
        "substring" | "slice" | "substr" => @ast.TsType::String_
        "concat" | "repeat" | "trim" | "toLowerCase" | "toUpperCase" =>
          @ast.TsType::String_
        "indexOf" | "lastIndexOf" | "localeCompare" => @ast.TsType::Int
        "split" => @ast.TsType::Array(@ast.TsType::String_)
        "startsWith" | "endsWith" | "includes" => @ast.TsType::Boolean
        _ => @ast.TsType::Any
      }
    @ast.TsType::Array(elem_type) =>
      match method_name {
        "push" | "unshift" => @ast.TsType::Int
        "pop" | "shift" => elem_type
        "slice" | "concat" | "filter" | "map" => @ast.TsType::Array(elem_type)
        "join" => @ast.TsType::String_
        "indexOf" | "lastIndexOf" | "findIndex" => @ast.TsType::Int
        "includes" | "every" | "some" => @ast.TsType::Boolean
        "find" => elem_type
        "reverse" | "sort" | "fill" => @ast.TsType::Array(elem_type)
        "reduce" | "reduceRight" => @ast.TsType::Any
        _ => @ast.TsType::Any
      }
    _ => @ast.TsType::Any
  }
}

///|
/// Infer expression and create typed expression.
pub fn infer_expr(ctx : TypeInferCtx, expr : @ast.TsExpr) -> @ast.TypedExpr {
  let type_ = infer_expr_type(ctx, expr)
  { expr, type_ }
}

///|
/// Collect local variable types from a function.
fn collect_local_types(
  ctx : TypeInferCtx,
  stmts : Array[@ast.TsStmt],
) -> Array[(String, @ast.TsType)] {
  let locals : Array[(String, @ast.TsType)] = []
  for stmt in stmts {
    collect_stmt_locals(ctx, stmt, locals)
  }
  locals
}

///|
fn collect_stmt_locals(
  ctx : TypeInferCtx,
  stmt : @ast.TsStmt,
  locals : Array[(String, @ast.TsType)],
) -> Unit {
  match stmt {
    @ast.TsStmt::Var(binding, type_, init) => {
      // Use context-aware type inference for better variable type tracking
      let resolved = resolve_any_with_ctx(ctx, type_, init)
      let names : Array[String] = []
      collect_binding_names(binding, names)
      for name in names {
        locals.push((name, resolved))
        ctx.add_var(name, resolved)
      }
    }
    @ast.TsStmt::Let(binding, type_, init) => {
      let resolved = resolve_any_with_ctx(ctx, type_, init)
      let names : Array[String] = []
      collect_binding_names(binding, names)
      for name in names {
        locals.push((name, resolved))
        ctx.add_var(name, resolved)
      }
    }
    @ast.TsStmt::Const(binding, type_, init) => {
      let resolved = resolve_any_with_ctx(ctx, type_, init)
      let names : Array[String] = []
      collect_binding_names(binding, names)
      for name in names {
        locals.push((name, resolved))
        ctx.add_var(name, resolved)
      }
    }
    @ast.TsStmt::For(init, _, _, body) => {
      match init {
        Some(init_stmt) => collect_stmt_locals(ctx, init_stmt, locals)
        None => ()
      }
      for s in body.stmts {
        collect_stmt_locals(ctx, s, locals)
      }
    }
    @ast.TsStmt::ForOf(_, binding, type_, _, body) => {
      let names : Array[String] = []
      collect_binding_names(binding, names)
      for name in names {
        locals.push((name, type_))
        ctx.add_var(name, type_)
      }
      for s in body.stmts {
        collect_stmt_locals(ctx, s, locals)
      }
    }
    @ast.TsStmt::ForAwaitOf(_, binding, type_, _, body) => {
      let names : Array[String] = []
      collect_binding_names(binding, names)
      for name in names {
        locals.push((name, type_))
        ctx.add_var(name, type_)
      }
      for s in body.stmts {
        collect_stmt_locals(ctx, s, locals)
      }
    }
    @ast.TsStmt::ForIn(_, binding, type_, _, body) => {
      let names : Array[String] = []
      collect_binding_names(binding, names)
      for name in names {
        locals.push((name, type_))
        ctx.add_var(name, type_)
      }
      for s in body.stmts {
        collect_stmt_locals(ctx, s, locals)
      }
    }
    @ast.TsStmt::While(_, body) =>
      for s in body.stmts {
        collect_stmt_locals(ctx, s, locals)
      }
    @ast.TsStmt::DoWhile(_, body) =>
      for s in body.stmts {
        collect_stmt_locals(ctx, s, locals)
      }
    @ast.TsStmt::If(_, then_block, else_block) => {
      for s in then_block.stmts {
        collect_stmt_locals(ctx, s, locals)
      }
      match else_block {
        Some(eb) =>
          for s in eb.stmts {
            collect_stmt_locals(ctx, s, locals)
          }
        None => ()
      }
    }
    @ast.TsStmt::Switch(_, cases) =>
      for case_ in cases {
        for s in case_.body.stmts {
          collect_stmt_locals(ctx, s, locals)
        }
      }
    @ast.TsStmt::Try(try_block, binding, catch_block, finally_block) => {
      for s in try_block.stmts {
        collect_stmt_locals(ctx, s, locals)
      }
      match binding {
        Some(b) => {
          let names : Array[String] = []
          collect_binding_names(b, names)
          for name in names {
            locals.push((name, @ast.TsType::Any))
            ctx.add_var(name, @ast.TsType::Any)
          }
        }
        None => ()
      }
      match catch_block {
        Some(cb) =>
          for s in cb.stmts {
            collect_stmt_locals(ctx, s, locals)
          }
        None => ()
      }
      match finally_block {
        Some(fb) =>
          for s in fb.stmts {
            collect_stmt_locals(ctx, s, locals)
          }
        None => ()
      }
    }
    @ast.TsStmt::Block(block) =>
      for s in block.stmts {
        collect_stmt_locals(ctx, s, locals)
      }
    @ast.TsStmt::With(_, body) =>
      for s in body.stmts {
        collect_stmt_locals(ctx, s, locals)
      }
    @ast.TsStmt::Label(_, inner) => collect_stmt_locals(ctx, inner, locals)
    _ => ()
  }
}

///|
/// Analyze a function and produce TypedFunc.
pub fn analyze_function(
  ctx : TypeInferCtx,
  func : @ast.TsFunc,
) -> @ast.TypedFunc {
  // Register function return type
  ctx.func_return_types[func.name] = func.return_type
  ctx.expected_return = func.return_type

  // Add parameters to context
  for param in func.params {
    ctx.add_var(param.name, param.type_)
  }

  // Collect local variable types
  let locals = collect_local_types(ctx, func.body.stmts)
  { func, locals }
}

///|
/// Analyze a module and produce TypedModule.
pub fn analyze_module_types(
  ctx : TypeInferCtx,
  module_ : @ast.TsModule,
) -> @ast.TypedModule {
  // First pass: register all function return types
  for func in module_.funcs {
    ctx.func_return_types[func.name] = func.return_type
  }

  // Second pass: analyze each function
  let typed_funcs : Array[@ast.TypedFunc] = []
  for func in module_.funcs {
    typed_funcs.push(analyze_function(ctx, func))
  }
  { funcs: typed_funcs }
}
