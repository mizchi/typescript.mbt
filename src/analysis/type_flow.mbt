// Flow-sensitive type tracking for type narrowing in conditionals.

///|
/// Scoped type environment that tracks type narrowing.
pub(all) struct TypeEnv {
  parent : TypeEnv?
  // Variable name -> narrowed type (only stores narrowed types)
  narrowed : Map[String, @ast.TsType]
  // Variables known to be truthy in this scope
  truthy : Array[String]
  // Variables known to be falsy in this scope
  falsy : Array[String]
}

///|
pub fn TypeEnv::new(parent : TypeEnv?) -> TypeEnv {
  { parent, narrowed: {}, truthy: [], falsy: [] }
}

///|
/// Get narrowed type for variable, walking up parent chain.
pub fn TypeEnv::get_narrowed(self : TypeEnv, name : String) -> @ast.TsType? {
  match self.narrowed.get(name) {
    Some(t) => Some(t)
    None =>
      match self.parent {
        Some(p) => p.get_narrowed(name)
        None => None
      }
  }
}

///|
/// Set narrowed type in current scope.
pub fn TypeEnv::set_narrowed(
  self : TypeEnv,
  name : String,
  type_ : @ast.TsType,
) -> Unit {
  self.narrowed[name] = type_
}

///|
/// Mark variable as truthy.
pub fn TypeEnv::mark_truthy(self : TypeEnv, name : String) -> Unit {
  self.truthy.push(name)
}

///|
/// Mark variable as falsy.
pub fn TypeEnv::mark_falsy(self : TypeEnv, name : String) -> Unit {
  self.falsy.push(name)
}

///|
/// Check if variable is known truthy.
pub fn TypeEnv::is_truthy(self : TypeEnv, name : String) -> Bool {
  if self.truthy.contains(name) {
    return true
  }
  match self.parent {
    Some(p) => p.is_truthy(name)
    None => false
  }
}

///|
/// Extended type inference context with flow analysis.
pub(all) struct FlowTypeCtx {
  base_ctx : TypeInferCtx
  mut type_env : TypeEnv
  registry : TypeRegistry
  solver : ConstraintSolver
  // Track return types for consistency checking
  mut return_types : Array[@ast.TsType]
}

///|
pub fn FlowTypeCtx::new(source : String) -> FlowTypeCtx {
  let registry = TypeRegistry::new()
  {
    base_ctx: TypeInferCtx::new(source),
    type_env: TypeEnv::new(None),
    registry,
    solver: ConstraintSolver::new(registry),
    return_types: [],
  }
}

///|
/// Enter a new type scope.
pub fn FlowTypeCtx::enter_scope(self : FlowTypeCtx) -> Unit {
  self.type_env = TypeEnv::new(Some(self.type_env))
}

///|
/// Leave current type scope.
pub fn FlowTypeCtx::leave_scope(self : FlowTypeCtx) -> Unit {
  match self.type_env.parent {
    Some(p) => self.type_env = p
    None => ()
  }
}

///|
/// Get variable type with narrowing applied.
pub fn FlowTypeCtx::get_type(self : FlowTypeCtx, name : String) -> @ast.TsType {
  // Check for narrowed type first
  match self.type_env.get_narrowed(name) {
    Some(t) => t
    None => self.base_ctx.get_var_type(name)
  }
}

///|
/// Set variable type.
pub fn FlowTypeCtx::set_type(
  self : FlowTypeCtx,
  name : String,
  type_ : @ast.TsType,
) -> Unit {
  self.base_ctx.add_var(name, type_)
}

///|
/// Narrow variable type in current scope.
pub fn FlowTypeCtx::narrow(
  self : FlowTypeCtx,
  name : String,
  type_ : @ast.TsType,
) -> Unit {
  self.type_env.set_narrowed(name, type_)
}

///|
/// Add type constraint.
pub fn FlowTypeCtx::add_constraint(
  self : FlowTypeCtx,
  constraint : TypeConstraint,
) -> Unit {
  self.solver.add_constraint(constraint)
}

///|
/// Record return type.
pub fn FlowTypeCtx::record_return(
  self : FlowTypeCtx,
  type_ : @ast.TsType,
) -> Unit {
  self.return_types.push(type_)
}

///|
/// Get unified return type.
pub fn FlowTypeCtx::get_return_type(self : FlowTypeCtx) -> @ast.TsType {
  if self.return_types.length() == 0 {
    return @ast.TsType::Void
  }
  if self.return_types.length() == 1 {
    return self.return_types[0]
  }
  // Unify multiple return types into union
  @ast.TsType::Union(self.return_types.copy())
}

///|
/// Analyze typeof guard condition.
pub fn analyze_typeof_guard(expr : @ast.TsExpr) -> (String, String)? {
  // Pattern: typeof x === "type" or typeof x !== "type"
  match expr {
    @ast.TsExpr::BinOp(
      op,
      @ast.TsExpr::UnaryOp(@ast.TsUnaryOp::Typeof, @ast.TsExpr::Var(name)),
      @ast.TsExpr::StringLit(type_str)
    ) =>
      match op {
        @ast.TsBinOp::BinEq | @ast.TsBinOp::AbstractEq => Some((name, type_str))
        _ => None
      }
    @ast.TsExpr::BinOp(
      op,
      @ast.TsExpr::StringLit(type_str),
      @ast.TsExpr::UnaryOp(@ast.TsUnaryOp::Typeof, @ast.TsExpr::Var(name))
    ) =>
      match op {
        @ast.TsBinOp::BinEq | @ast.TsBinOp::AbstractEq => Some((name, type_str))
        _ => None
      }
    _ => None
  }
}

///|
/// Analyze truthiness guard (if x).
pub fn analyze_truthiness_guard(expr : @ast.TsExpr) -> String? {
  match expr {
    @ast.TsExpr::Var(name) => Some(name)
    _ => None
  }
}

///|
/// Analyze null check guard (x !== null, x != null).
pub fn analyze_null_guard(expr : @ast.TsExpr) -> (String, Bool)? {
  match expr {
    @ast.TsExpr::BinOp(op, @ast.TsExpr::Var(name), @ast.TsExpr::NullLit) =>
      match op {
        @ast.TsBinOp::BinNe | @ast.TsBinOp::AbstractNe => Some((name, true)) // is not null
        @ast.TsBinOp::BinEq | @ast.TsBinOp::AbstractEq => Some((name, false)) // is null
        _ => None
      }
    @ast.TsExpr::BinOp(op, @ast.TsExpr::NullLit, @ast.TsExpr::Var(name)) =>
      match op {
        @ast.TsBinOp::BinNe | @ast.TsBinOp::AbstractNe => Some((name, true)) // is not null
        @ast.TsBinOp::BinEq | @ast.TsBinOp::AbstractEq => Some((name, false)) // is null
        _ => None
      }
    _ => None
  }
}

///|
/// Remove null/undefined from union type.
pub fn remove_null_undefined(t : @ast.TsType) -> @ast.TsType {
  match t {
    @ast.TsType::Union(types) => {
      let filtered = types.filter(fn(inner) {
        match inner {
          @ast.TsType::Null | @ast.TsType::Undefined => false
          _ => true
        }
      })
      if filtered.length() == 1 {
        filtered[0]
      } else if filtered.length() > 1 {
        @ast.TsType::Union(filtered)
      } else {
        @ast.TsType::Never
      }
    }
    @ast.TsType::Null | @ast.TsType::Undefined => @ast.TsType::Never
    _ => t
  }
}

///|
/// Remove falsy types from type.
pub fn remove_falsy(t : @ast.TsType) -> @ast.TsType {
  match t {
    @ast.TsType::Union(types) => {
      let filtered = types.filter(fn(inner) {
        match inner {
          @ast.TsType::Null | @ast.TsType::Undefined => false
          @ast.TsType::Literal("") => false
          _ => true
        }
      })
      if filtered.length() == 1 {
        filtered[0]
      } else if filtered.length() > 1 {
        @ast.TsType::Union(filtered)
      } else {
        @ast.TsType::Never
      }
    }
    @ast.TsType::Null | @ast.TsType::Undefined => @ast.TsType::Never
    _ => t
  }
}

///|
/// Compute the intersection of two types (for && narrowing).
pub fn intersect_types(a : @ast.TsType, b : @ast.TsType) -> @ast.TsType {
  if a == b {
    return a
  }
  if a == @ast.TsType::Any {
    return b
  }
  if b == @ast.TsType::Any {
    return a
  }
  if a == @ast.TsType::Never || b == @ast.TsType::Never {
    return @ast.TsType::Never
  }
  // For now, just use the more specific type
  if is_assignable(a, b) {
    return a
  }
  if is_assignable(b, a) {
    return b
  }
  @ast.TsType::Intersection([a, b])
}

///|
/// Compute the union of two types (for || / conditional paths).
pub fn union_types(a : @ast.TsType, b : @ast.TsType) -> @ast.TsType {
  if a == b {
    return a
  }
  if a == @ast.TsType::Any || b == @ast.TsType::Any {
    return @ast.TsType::Any
  }
  if a == @ast.TsType::Never {
    return b
  }
  if b == @ast.TsType::Never {
    return a
  }
  @ast.TsType::Union([a, b])
}
