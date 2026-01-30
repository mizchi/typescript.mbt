// Main entry point for static analysis.

///|
/// Analyze a parsed module and produce a TypedModule.
/// Returns errors if binding or type analysis fails.
pub fn analyze(
  module_ : @ast.TsModule,
  source : String,
) -> AnalysisResult[@ast.TypedModule] {
  // Create analysis context
  let ctx = AnalysisCtx::new(source)

  // Run binding analysis
  analyze_module_bindings(ctx, module_)

  // Check for errors
  if ctx.has_errors() {
    return Err(ctx.errors)
  }

  // Run type inference
  let type_ctx = TypeInferCtx::new(source)
  let typed_module = analyze_module_types(type_ctx, module_)
  Ok(typed_module, ctx.warnings)
}

///|
/// Analyze a block and check for binding errors.
pub fn analyze_block(
  block : @ast.TsBlock,
  source : String,
) -> AnalysisResult[Unit] {
  let ctx = AnalysisCtx::new(source)

  // Hoist var declarations
  hoist_declarations(ctx, block)

  // Analyze bindings
  analyze_block_bindings(ctx, block)
  if ctx.has_errors() {
    Err(ctx.errors)
  } else {
    Ok((), ctx.warnings)
  }
}

///|
/// Analyze a function and check for binding errors.
pub fn analyze_func(
  func : @ast.TsFunc,
  source : String,
) -> AnalysisResult[@ast.TypedFunc] {
  let ctx = AnalysisCtx::new(source)

  // Run binding analysis
  analyze_function_bindings(ctx, func)
  if ctx.has_errors() {
    return Err(ctx.errors)
  }

  // Run type inference
  let type_ctx = TypeInferCtx::new(source)
  let typed_func = analyze_function(type_ctx, func)
  Ok(typed_func, ctx.warnings)
}

///|
/// Parse and analyze source code.
pub fn parse_and_analyze(source : String) -> AnalysisResult[@ast.TypedModule] {
  // Parse source
  let parser = @parser.Parser::from_source(source)
  try {
    let module_ = parser.parse_module()
    // Analyze
    analyze(module_, source)
  } catch {
    @parser.ParseError(msg) =>
      Err([{ kind: SyntaxError, message: msg, loc: SourceLoc::unknown() }])
  }
}

///|
/// Check if source code has any static errors.
pub fn check(source : String) -> Array[AnalysisError] {
  let result = parse_and_analyze(source)
  result.get_errors()
}

///|
/// Analyze expression for type.
pub fn analyze_expr_type(expr : @ast.TsExpr, source : String) -> @ast.TsType {
  let ctx = TypeInferCtx::new(source)
  infer_expr_type(ctx, expr)
}

///|
/// Full analysis result including usage tracking.
pub(all) struct FullAnalysisResult {
  typed_module : @ast.TypedModule
  symbol_table : SymbolTable
  drop_analysis : DropAnalysis
  warnings : Array[AnalysisError]
}

///|
/// Analyze a module with full usage tracking and drop point analysis.
/// This is the preferred entry point for codegen as it provides:
/// - Type inference results
/// - Symbol usage tracking
/// - Perceus-style drop point analysis
pub fn analyze_full(
  module_ : @ast.TsModule,
  source : String,
) -> AnalysisResult[FullAnalysisResult] {
  // Run binding analysis
  let ctx = AnalysisCtx::new(source)
  analyze_module_bindings(ctx, module_)
  if ctx.has_errors() {
    return Err(ctx.errors)
  }

  // Run type inference
  let type_ctx = TypeInferCtx::new(source)
  let typed_module = analyze_module_types(type_ctx, module_)

  // Run usage tracking
  let symbol_table = analyze_usage(module_, source)
  let drop_analysis = symbol_table.get_drop_analysis()

  // Add warnings for unused variables
  for name in drop_analysis.never_used {
    ctx.add_warning("'\{name}' is declared but never used", 0)
  }
  Ok(
    { typed_module, symbol_table, drop_analysis, warnings: ctx.warnings },
    ctx.warnings,
  )
}
