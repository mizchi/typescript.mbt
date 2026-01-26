// TypeScript サブセット用レキサー

///|
/// トークン種別
pub enum TokenKind {
  // リテラル
  Number(Double)
  Int(Int)
  Bool(Bool)
  Str(String) // 文字列リテラル
  Regex(String, String) // /pattern/flags
  Ident(String)

  // キーワード
  Function
  Class
  Extends
  Var
  Let
  Const
  Return
  If
  Else
  While
  Do
  For
  Break
  Continue
  True
  False
  Typeof

  // 型キーワード
  NumberType // number
  BooleanType // boolean
  VoidType // void
  IntType // int (拡張)
  StringType // string

  // 演算子
  Plus // +
  Minus // -
  Star // *
  Slash // /
  Percent // %
  EqEq // ==
  EqEqEq // ===
  BangEq // !=
  BangEqEq // !==
  Instanceof // instanceof
  Lt // <
  Le // <=
  Gt // >
  Ge // >=
  AmpAmp // &&
  PipePipe // ||
  Bang // !
  Eq // =
  Question // ?
  PlusPlus // ++
  MinusMinus // --
  PlusEq // +=
  MinusEq // -=
  StarEq // *=
  SlashEq // /=
  Arrow // =>
  Ellipsis // ...

  // 区切り
  LParen // (
  RParen // )
  LBrace // {
  RBrace // }
  LBracket // [
  RBracket // ]
  Comma // ,
  Colon // :
  Semicolon // ;
  Dot // .

  // キーワード (追加)
  New // new
  Interface // interface
  Type // type (type alias)
  Of // of (for...of)
  In // in (for...in)
  Declare // declare (外部インポート宣言)
  Null // null

  // 終端
  Eof
} derive(Eq, Show)

///|
/// トークン
pub struct Token {
  kind : TokenKind
  pos : Int // 開始位置
} derive(Show)

///|
/// レキサー
pub struct Lexer {
  src : String
  mut pos : Int
  mut allow_regex : Bool
} derive(Show)

///|
/// レキサー作成
pub fn Lexer::new(src : String) -> Lexer {
  { src, pos: 0, allow_regex: true }
}

///|
/// 現在の文字を取得
fn Lexer::peek(self : Lexer) -> Char? {
  if self.pos >= self.src.length() {
    None
  } else {
    Some(self.src[self.pos].to_int().unsafe_to_char())
  }
}

///|
/// 次の文字を覗く
fn Lexer::peek_next(self : Lexer) -> Char? {
  if self.pos + 1 >= self.src.length() {
    None
  } else {
    Some(self.src[self.pos + 1].to_int().unsafe_to_char())
  }
}

///|
/// 文字を消費
fn Lexer::advance(self : Lexer) -> Char? {
  let c = self.peek()
  if c is Some(_) {
    self.pos += 1
  }
  c
}

///|
/// 空白をスキップ
fn Lexer::skip_whitespace(self : Lexer) -> Unit {
  while true {
    match self.peek() {
      Some(' ') | Some('\t') | Some('\n') | Some('\r') => {
        let _ = self.advance()

      }
      // コメントスキップ
      Some('/') =>
        match self.peek_next() {
          Some('/') => {
            // 行コメント
            let _ = self.advance()
            let _ = self.advance()
            while true {
              match self.peek() {
                Some('\n') | None => break
                _ => {
                  let _ = self.advance()

                }
              }
            }
          }
          Some('*') => {
            // ブロックコメント
            let _ = self.advance()
            let _ = self.advance()
            while true {
              match self.peek() {
                None => break
                Some('*') =>
                  match self.peek_next() {
                    Some('/') => {
                      let _ = self.advance()
                      let _ = self.advance()
                      break
                    }
                    _ => {
                      let _ = self.advance()

                    }
                  }
                _ => {
                  let _ = self.advance()

                }
              }
            }
          }
          _ => break
        }
      _ => break
    }
  }
}

///|
/// 数値リテラルをパース
fn Lexer::scan_number(self : Lexer) -> TokenKind {
  let start = self.pos
  // Radix-prefixed integers: 0x / 0o / 0b
  if self.peek() == Some('0') {
    match self.peek_next() {
      Some('x') | Some('X') => {
        let _ = self.advance()
        let _ = self.advance()
        let mut value = 0
        let mut has_digit = false
        while true {
          match self.peek() {
            Some('_') => {
              let _ = self.advance()
            }
            Some(c) =>
              match c {
                '0' => {
                  let _ = self.advance()
                  value = value * 16 + 0
                  has_digit = true
                }
                '1' => {
                  let _ = self.advance()
                  value = value * 16 + 1
                  has_digit = true
                }
                '2' => {
                  let _ = self.advance()
                  value = value * 16 + 2
                  has_digit = true
                }
                '3' => {
                  let _ = self.advance()
                  value = value * 16 + 3
                  has_digit = true
                }
                '4' => {
                  let _ = self.advance()
                  value = value * 16 + 4
                  has_digit = true
                }
                '5' => {
                  let _ = self.advance()
                  value = value * 16 + 5
                  has_digit = true
                }
                '6' => {
                  let _ = self.advance()
                  value = value * 16 + 6
                  has_digit = true
                }
                '7' => {
                  let _ = self.advance()
                  value = value * 16 + 7
                  has_digit = true
                }
                '8' => {
                  let _ = self.advance()
                  value = value * 16 + 8
                  has_digit = true
                }
                '9' => {
                  let _ = self.advance()
                  value = value * 16 + 9
                  has_digit = true
                }
                'a' | 'A' => {
                  let _ = self.advance()
                  value = value * 16 + 10
                  has_digit = true
                }
                'b' | 'B' => {
                  let _ = self.advance()
                  value = value * 16 + 11
                  has_digit = true
                }
                'c' | 'C' => {
                  let _ = self.advance()
                  value = value * 16 + 12
                  has_digit = true
                }
                'd' | 'D' => {
                  let _ = self.advance()
                  value = value * 16 + 13
                  has_digit = true
                }
                'e' | 'E' => {
                  let _ = self.advance()
                  value = value * 16 + 14
                  has_digit = true
                }
                'f' | 'F' => {
                  let _ = self.advance()
                  value = value * 16 + 15
                  has_digit = true
                }
                _ => break
              }
            None => break
          }
        }
        if not(has_digit) {
          value = 0
        }
        let mut is_bigint = false
        if self.peek() == Some('n') {
          is_bigint = true
          let _ = self.advance()
        }
        if is_bigint {
          return Number(value.to_double())
        } else {
          return Int(value)
        }
      }
      Some('b') | Some('B') => {
        let _ = self.advance()
        let _ = self.advance()
        let mut value = 0
        let mut has_digit = false
        while true {
          match self.peek() {
            Some('_') => {
              let _ = self.advance()
            }
            Some('0') => {
              let _ = self.advance()
              value = value * 2
              has_digit = true
            }
            Some('1') => {
              let _ = self.advance()
              value = value * 2 + 1
              has_digit = true
            }
            _ => break
          }
        }
        if not(has_digit) {
          value = 0
        }
        let mut is_bigint = false
        if self.peek() == Some('n') {
          is_bigint = true
          let _ = self.advance()
        }
        if is_bigint {
          return Number(value.to_double())
        } else {
          return Int(value)
        }
      }
      Some('o') | Some('O') => {
        let _ = self.advance()
        let _ = self.advance()
        let mut value = 0
        let mut has_digit = false
        while true {
          match self.peek() {
            Some('_') => {
              let _ = self.advance()
            }
            Some('0') => {
              let _ = self.advance()
              value = value * 8 + 0
              has_digit = true
            }
            Some('1') => {
              let _ = self.advance()
              value = value * 8 + 1
              has_digit = true
            }
            Some('2') => {
              let _ = self.advance()
              value = value * 8 + 2
              has_digit = true
            }
            Some('3') => {
              let _ = self.advance()
              value = value * 8 + 3
              has_digit = true
            }
            Some('4') => {
              let _ = self.advance()
              value = value * 8 + 4
              has_digit = true
            }
            Some('5') => {
              let _ = self.advance()
              value = value * 8 + 5
              has_digit = true
            }
            Some('6') => {
              let _ = self.advance()
              value = value * 8 + 6
              has_digit = true
            }
            Some('7') => {
              let _ = self.advance()
              value = value * 8 + 7
              has_digit = true
            }
            _ => break
          }
        }
        if not(has_digit) {
          value = 0
        }
        let mut is_bigint = false
        if self.peek() == Some('n') {
          is_bigint = true
          let _ = self.advance()
        }
        if is_bigint {
          return Number(value.to_double())
        } else {
          return Int(value)
        }
      }
      _ => ()
    }
  }
  let mut has_dot = false
  let mut has_exp = false
  let mut is_bigint = false
  while true {
    match self.peek() {
      Some(c) =>
        if c >= '0' && c <= '9' {
          let _ = self.advance()

        } else if c == '_' {
          let _ = self.advance()
        } else if c == '.' && not(has_dot) && not(has_exp) {
          has_dot = true
          let _ = self.advance()

        } else if (c == 'e' || c == 'E') && not(has_exp) {
          has_exp = true
          let _ = self.advance()
          match self.peek() {
            Some('+') | Some('-') => {
              let _ = self.advance()

            }
            _ => ()
          }
        } else {
          break
        }
      None => break
    }
  }
  if self.peek() == Some('n') {
    is_bigint = true
    let _ = self.advance()
  }
  let s = try { self.src[start:self.pos].to_string() } catch { _ => "" }
  let cleaned = StringBuilder::new()
  for ch in s {
    if ch == '_' {
      continue
    }
    if is_bigint && ch == 'n' {
      continue
    }
    cleaned.write_char(ch)
  }
  let cleaned_s = cleaned.to_string()
  if has_dot || has_exp || is_bigint {
    // Double としてパース
    try {
      let d = @strconv.parse_double(cleaned_s)
      Number(d)
    } catch {
      _ => Number(0.0)
    }
  } else {
    // Int としてパース
    try {
      let i = @strconv.parse_int(cleaned_s)
      Int(i)
    } catch {
      _ => Int(0)
    }
  }
}

///|
/// 識別子/キーワードをパース
fn Lexer::scan_ident(self : Lexer) -> TokenKind {
  let start = self.pos
  while true {
    match self.peek() {
      Some(c) =>
        if (c >= 'a' && c <= 'z') ||
          (c >= 'A' && c <= 'Z') ||
          (c >= '0' && c <= '9') ||
          c == '_' ||
          c == '$' {
          let _ = self.advance()

        } else {
          break
        }
      None => break
    }
  }
  let s = try { self.src[start:self.pos].to_string() } catch { _ => "" }

  // キーワードチェック
  match s {
    "function" => Function
    "class" => Class
    "extends" => Extends
    "var" => Var
    "let" => Let
    "const" => Const
    "return" => Return
    "if" => If
    "else" => Else
    "while" => While
    "do" => Do
    "for" => For
    "break" => Break
    "continue" => Continue
    "true" => Bool(true)
    "false" => Bool(false)
    "typeof" => Typeof
    "null" => Null
    "number" => NumberType
    "boolean" => BooleanType
    "void" => VoidType
    "int" => IntType
    "string" => StringType
    "new" => New
    "interface" => Interface
    "type" => Type
    "of" => Of
    "in" => In
    "declare" => Declare
    "instanceof" => Instanceof
    _ => Ident(s)
  }
}

///|
/// 文字列リテラルをパース
fn Lexer::scan_string(self : Lexer, quote : Char) -> TokenKind {
  let buf = StringBuilder::new()
  while true {
    match self.peek() {
      None => break // 終端（エラーだが簡易処理）
      Some(c) =>
        if c == quote {
          let _ = self.advance() // 閉じ引用符を消費
          break
        } else if c == '\\' {
          // エスケープシーケンス
          let _ = self.advance()
          match self.peek() {
            Some('n') => {
              let _ = self.advance()
              buf.write_char('\n')
            }
            Some('t') => {
              let _ = self.advance()
              buf.write_char('\t')
            }
            Some('r') => {
              let _ = self.advance()
              buf.write_char('\r')
            }
            Some('\\') => {
              let _ = self.advance()
              buf.write_char('\\')
            }
            Some('\'') => {
              let _ = self.advance()
              buf.write_char('\'')
            }
            Some('"') => {
              let _ = self.advance()
              buf.write_char('"')
            }
            Some(other) => {
              let _ = self.advance()
              buf.write_char(other) // 不明なエスケープはそのまま
            }
            None => break
          }
        } else {
          let _ = self.advance()
          buf.write_char(c)
        }
    }
  }
  Str(buf.to_string())
}

///|
/// 正規表現リテラルをパース (/pattern/flags)
fn Lexer::scan_regex(self : Lexer) -> TokenKind {
  let buf = StringBuilder::new()
  let mut in_class = false
  let mut escaped = false
  while true {
    match self.peek() {
      None => break
      Some(c) => {
        let _ = self.advance()
        if escaped {
          buf.write_char(c)
          escaped = false
          continue
        }
        if c == '\\' {
          buf.write_char(c)
          escaped = true
          continue
        }
        if c == '[' {
          in_class = true
        } else if c == ']' {
          in_class = false
        }
        if c == '/' && not(in_class) {
          break
        }
        buf.write_char(c)
      }
    }
  }
  let flags = StringBuilder::new()
  while true {
    match self.peek() {
      Some(c) =>
        if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
          let _ = self.advance()
          flags.write_char(c)
        } else {
          break
        }
      None => break
    }
  }
  Regex(buf.to_string(), flags.to_string())
}

///|
/// 式を終端できるトークンか
fn token_can_end_expr(kind : TokenKind) -> Bool {
  match kind {
    Number(_)
    | Int(_)
    | Bool(_)
    | Str(_)
    | Regex(_, _)
    | Ident(_)
    | Null
    | RParen
    | RBracket
    | RBrace
    | PlusPlus
    | MinusMinus => true
    _ => false
  }
}

///|
/// 次のトークンを取得
pub fn Lexer::next_token(self : Lexer) -> Token {
  self.skip_whitespace()
  let pos = self.pos
  match self.advance() {
    None => { kind: Eof, pos }
    Some(c) => {
      let kind : TokenKind = match c {
        // 数値
        '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' => {
          self.pos -= 1 // 戻す
          self.scan_number()
        }
        // 識別子/キーワード
        'a'
        | 'b'
        | 'c'
        | 'd'
        | 'e'
        | 'f'
        | 'g'
        | 'h'
        | 'i'
        | 'j'
        | 'k'
        | 'l'
        | 'm'
        | 'n'
        | 'o'
        | 'p'
        | 'q'
        | 'r'
        | 's'
        | 't'
        | 'u'
        | 'v'
        | 'w'
        | 'x'
        | 'y'
        | 'z'
        | 'A'
        | 'B'
        | 'C'
        | 'D'
        | 'E'
        | 'F'
        | 'G'
        | 'H'
        | 'I'
        | 'J'
        | 'K'
        | 'L'
        | 'M'
        | 'N'
        | 'O'
        | 'P'
        | 'Q'
        | 'R'
        | 'S'
        | 'T'
        | 'U'
        | 'V'
        | 'W'
        | 'X'
        | 'Y'
        | 'Z'
        | '_'
        | '$' => {
          self.pos -= 1
          self.scan_ident()
        }
        // 演算子
        '+' =>
          match self.peek() {
            Some('+') => {
              let _ = self.advance()
              PlusPlus
            }
            Some('=') => {
              let _ = self.advance()
              PlusEq
            }
            _ => Plus
          }
        '-' =>
          match self.peek() {
            Some('-') => {
              let _ = self.advance()
              MinusMinus
            }
            Some('=') => {
              let _ = self.advance()
              MinusEq
            }
            _ => Minus
          }
        '*' =>
          match self.peek() {
            Some('=') => {
              let _ = self.advance()
              StarEq
            }
            _ => Star
          }
        '/' =>
          match self.peek() {
            Some('=') => {
              let _ = self.advance()
              SlashEq
            }
            _ =>
              if self.allow_regex {
                self.scan_regex()
              } else {
                Slash
              }
          }
        '%' => Percent
        '?' => Question
        '=' =>
          match self.peek() {
            Some('=') =>
              match self.peek_next() {
                Some('=') => {
                  let _ = self.advance()
                  let _ = self.advance()
                  EqEqEq
                }
                _ => {
                  let _ = self.advance()
                  EqEq
                }
              }
            Some('>') => {
              let _ = self.advance()
              Arrow
            }
            _ => Eq
          }
        '!' =>
          match self.peek() {
            Some('=') =>
              match self.peek_next() {
                Some('=') => {
                  let _ = self.advance()
                  let _ = self.advance()
                  BangEqEq
                }
                _ => {
                  let _ = self.advance()
                  BangEq
                }
              }
            _ => Bang
          }
        '<' =>
          match self.peek() {
            Some('=') => {
              let _ = self.advance()
              Le
            }
            _ => Lt
          }
        '>' =>
          match self.peek() {
            Some('=') => {
              let _ = self.advance()
              Ge
            }
            _ => Gt
          }
        '&' =>
          match self.peek() {
            Some('&') => {
              let _ = self.advance()
              AmpAmp
            }
            _ => Bang // エラー扱い
          }
        '|' =>
          match self.peek() {
            Some('|') => {
              let _ = self.advance()
              PipePipe
            }
            _ => Bang // エラー扱い
          }
        // 区切り
        '(' => LParen
        ')' => RParen
        '{' => LBrace
        '}' => RBrace
        '[' => LBracket
        ']' => RBracket
        ',' => Comma
        ':' => Colon
        ';' => Semicolon
        '.' =>
          match self.peek() {
            Some('0'..='9') => {
              self.pos -= 1
              self.scan_number()
            }
            Some('.') =>
              match self.peek_next() {
                Some('.') => {
                  let _ = self.advance()
                  let _ = self.advance()
                  Ellipsis
                }
                _ => Dot
              }
            _ => Dot
          }
        '"' | '\'' => {
          // 文字列リテラル
          let quote = c
          self.scan_string(quote)
        }
        _ => Eof // 未知の文字
      }
      self.allow_regex = not(token_can_end_expr(kind))
      { kind, pos }
    }
  }
}

///|
/// すべてのトークンを取得
pub fn Lexer::tokenize(self : Lexer) -> Array[Token] {
  let tokens : Array[Token] = []
  while true {
    let tok = self.next_token()
    tokens.push(tok)
    if tok.kind == Eof {
      break
    }
  }
  tokens
}
