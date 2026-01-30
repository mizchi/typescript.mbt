///|
fn is_leap_year(year : Int) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

///|
fn days_in_year(year : Int) -> Int {
  if is_leap_year(year) {
    366
  } else {
    365
  }
}

///|
fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    0 => 31
    1 => if is_leap_year(year) { 29 } else { 28 }
    2 => 31
    3 => 30
    4 => 31
    5 => 30
    6 => 31
    7 => 31
    8 => 30
    9 => 31
    10 => 30
    11 => 31
    _ => 30
  }
}

///|
fn floor_div(a : Int, b : Int) -> Int {
  if b == 0 {
    0
  } else if a >= 0 {
    a / b
  } else {
    -((-a + b - 1) / b)
  }
}

///|
fn days_before_year(year : Int) -> Int {
  let mut days = 0
  if year >= 1970 {
    let mut y = 1970
    while y < year {
      days += days_in_year(y)
      y += 1
    }
  } else {
    let mut y = year
    while y < 1970 {
      days -= days_in_year(y)
      y += 1
    }
  }
  days
}

///|
fn days_before_month(year : Int, month : Int) -> Int {
  let mut days = 0
  let mut m = 0
  while m < month {
    days += days_in_month(year, m)
    m += 1
  }
  days
}

///|
fn make_date_time(
  year : Int,
  month : Int,
  date : Int,
  hour : Int,
  minute : Int,
  second : Int,
  ms : Int,
) -> Double {
  let q = floor_div(month, 12)
  let mut y = year + q
  let mut m = month - q * 12
  if m < 0 {
    m += 12
    y -= 1
  }
  let day = days_before_year(y) + days_before_month(y, m) + (date - 1)
  let time_ms = ((hour * 60 + minute) * 60 + second) * 1000 + ms
  day.to_double() * 86400000.0 + time_ms.to_double()
}

///|
fn break_time(t : Double) -> (Int, Int, Int, Int, Int, Int, Int) {
  let day = (t / 86400000.0).floor()
  let mut days = day.to_int()
  let time_ms = t - day * 86400000.0
  let time_ms_int = time_ms.to_int()
  let mut year = 1970
  if days >= 0 {
    while days >= days_in_year(year) {
      days -= days_in_year(year)
      year += 1
    }
  } else {
    year = 1969
    while days < 0 {
      days += days_in_year(year)
      year -= 1
    }
    year += 1
  }
  let mut month = 0
  while days >= days_in_month(year, month) {
    days -= days_in_month(year, month)
    month += 1
  }
  let day = days + 1
  let hour = time_ms_int / 3600000
  let mut rem = time_ms_int - hour * 3600000
  let minute = rem / 60000
  rem = rem - minute * 60000
  let second = rem / 1000
  let milli = rem - second * 1000
  (year, month, day, hour, minute, second, milli)
}

///|
fn time_clip(t : Double) -> Double {
  if t.is_nan() || t.is_inf() {
    return js_nan
  }
  let abs = if t < 0.0 { -t } else { t }
  if abs > 8.64e15 {
    js_nan
  } else {
    t.trunc()
  }
}

///|
fn JSInterpreter::date_time_value(
  self : JSInterpreter,
  this_arg : JSValue,
) -> Double? {
  match this_arg {
    Object(_) | Array(_) | Function(_) => ()
    _ => {
      let _ = self.set_error_kind("TypeError", "Not a Date object")
      return None
    }
  }
  match js_get_prop(this_arg, "__class") {
    String("Date") => ()
    _ => {
      let _ = self.set_error_kind("TypeError", "Not a Date object")
      return None
    }
  }
  match js_get_prop(this_arg, "__date_value") {
    Number(n) => Some(n)
    _ => Some(js_nan)
  }
}
