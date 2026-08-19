///|
/// Three-byte CP24Time2a value used by short time-tagged ASDUs.
pub struct Cp24Time {
  millisecond : Int
  minute : Int
} derive(Eq, Debug)

///|
pub fn Cp24Time::new(
  millisecond : Int,
  minute : Int,
) -> Result[Cp24Time, String] {
  if millisecond < 0 || millisecond > 59999 {
    Err("CP24 millisecond field must be between 0 and 59999")
  } else if minute < 0 || minute > 59 {
    Err("CP24 minute field must be between 0 and 59")
  } else {
    Ok({ millisecond, minute })
  }
}

///|
pub fn Cp24Time::millisecond(self : Cp24Time) -> Int {
  self.millisecond
}

///|
pub fn Cp24Time::minute(self : Cp24Time) -> Int {
  self.minute
}

///|
pub fn Cp24Time::second(self : Cp24Time) -> Int {
  self.millisecond / 1000
}

///|
pub fn Cp24Time::remainder_millisecond(self : Cp24Time) -> Int {
  self.millisecond % 1000
}

///|
pub fn Cp24Time::to_array(self : Cp24Time) -> Array[Byte] {
  [
    (self.millisecond & 0xff).to_byte(),
    ((self.millisecond >> 8) & 0xff).to_byte(),
    self.minute.to_byte(),
  ]
}

///|
pub fn Cp24Time::from_bytes(
  data : Bytes,
  offset? : Int = 0,
) -> Result[Cp24Time, String] {
  if offset < 0 || data.length() < offset + 3 {
    Err("CP24 value is truncated")
  } else {
    let millisecond = data[offset].to_int() | (data[offset + 1].to_int() << 8)
    Cp24Time::new(millisecond, data[offset + 2].to_int())
  }
}

///|
/// Whether a year is a Gregorian leap year.
pub fn is_leap_year(year : Int) -> Bool {
  year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)
}

///|
/// Return the number of days in a Gregorian month.
pub fn days_in_month(year : Int, month : Int) -> Int? {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => Some(31)
    4 | 6 | 9 | 11 => Some(30)
    2 => Some(if is_leap_year(year) { 29 } else { 28 })
    _ => None
  }
}

///|
/// Seven-byte CP56Time2a timestamp.
pub struct Cp56Time {
  year : Int
  month : Int
  day : Int
  weekday : Int
  hour : Int
  minute : Int
  millisecond : Int
} derive(Eq, Debug)

///|
/// Construct a CP56 timestamp. The year is the two-digit protocol year.
pub fn Cp56Time::new(
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  millisecond : Int,
  weekday? : Int = 0,
) -> Result[Cp56Time, String] {
  if year < 0 || year > 99 {
    Err("CP56 year must be between 0 and 99")
  } else if month < 1 || month > 12 {
    Err("CP56 month must be between 1 and 12")
  } else if day < 1 || day > days_in_month(2000 + year, month).unwrap() {
    Err("CP56 day is outside the selected month")
  } else if weekday < 0 || weekday > 7 {
    Err("CP56 weekday must be between 0 and 7")
  } else if hour < 0 || hour > 23 {
    Err("CP56 hour must be between 0 and 23")
  } else if minute < 0 || minute > 59 {
    Err("CP56 minute must be between 0 and 59")
  } else if millisecond < 0 || millisecond > 59999 {
    Err("CP56 millisecond field must be between 0 and 59999")
  } else {
    Ok({ year, month, day, weekday, hour, minute, millisecond })
  }
}

///|
pub fn Cp56Time::year(self : Cp56Time) -> Int {
  self.year
}

///|
pub fn Cp56Time::month(self : Cp56Time) -> Int {
  self.month
}

///|
pub fn Cp56Time::day(self : Cp56Time) -> Int {
  self.day
}

///|
pub fn Cp56Time::weekday(self : Cp56Time) -> Int {
  self.weekday
}

///|
pub fn Cp56Time::hour(self : Cp56Time) -> Int {
  self.hour
}

///|
pub fn Cp56Time::minute(self : Cp56Time) -> Int {
  self.minute
}

///|
pub fn Cp56Time::millisecond(self : Cp56Time) -> Int {
  self.millisecond
}

///|
pub fn Cp56Time::second(self : Cp56Time) -> Int {
  self.millisecond / 1000
}

///|
pub fn Cp56Time::remainder_millisecond(self : Cp56Time) -> Int {
  self.millisecond % 1000
}

///|
/// Return the four-digit calendar year represented by the protocol year.
pub fn Cp56Time::calendar_year(self : Cp56Time, century? : Int = 2000) -> Int {
  century + self.year
}

///|
pub fn Cp56Time::to_array(self : Cp56Time) -> Array[Byte] {
  [
    (self.millisecond & 0xff).to_byte(),
    ((self.millisecond >> 8) & 0xff).to_byte(),
    self.minute.to_byte(),
    self.hour.to_byte(),
    (self.day | (self.weekday << 5)).to_byte(),
    self.month.to_byte(),
    self.year.to_byte(),
  ]
}

///|
pub fn Cp56Time::from_bytes(
  data : Bytes,
  offset? : Int = 0,
) -> Result[Cp56Time, String] {
  if offset < 0 || data.length() < offset + 7 {
    Err("CP56 value is truncated")
  } else {
    let millisecond = data[offset].to_int() | (data[offset + 1].to_int() << 8)
    let minute = data[offset + 2].to_int()
    let hour = data[offset + 3].to_int()
    let day_field = data[offset + 4].to_int()
    Cp56Time::new(
      data[offset + 6].to_int(),
      data[offset + 5].to_int(),
      day_field & 0x1f,
      hour,
      minute,
      millisecond,
      weekday=day_field >> 5,
    )
  }
}

///|
/// Calculate ISO-like weekday for a Gregorian date: Monday is 1, Sunday is 7.
pub fn calendar_weekday(
  year : Int,
  month : Int,
  day : Int,
) -> Result[Int, String] {
  if month < 1 || month > 12 {
    Err("month must be between 1 and 12")
  } else if day < 1 || day > days_in_month(year, month).unwrap() {
    Err("day is outside the selected month")
  } else {
    let adjusted_year = if month < 3 { year - 1 } else { year }
    let adjusted_month = if month < 3 { month + 12 } else { month }
    let k = adjusted_year % 100
    let j = adjusted_year / 100
    let h = (day + 13 * (adjusted_month + 1) / 5 + k + k / 4 + j / 4 + 5 * j) %
      7
    Ok(if h == 0 { 6 } else { h - 1 })
  }
}

///|
/// Tag precision carried by a time-tagged application object.
pub enum TimeTagKind {
  NoTimeTag
  Cp24TimeTag
  Cp56TimeTag
} derive(Eq, Debug)

///|
pub fn TimeTagKind::width(self : TimeTagKind) -> Int {
  match self {
    NoTimeTag => 0
    Cp24TimeTag => 3
    Cp56TimeTag => 7
  }
}

///|
pub fn time_tag_kind_for_type(type_id : ApplicationType) -> TimeTagKind {
  match type_id {
    MSpTa | MDpTa | MStTa | MBoTa | MMeTa | MMeTb | MMeTc | MItTa => Cp24TimeTag
    MSpTb | MDpTb | MStTb | MBoTb | MMeTd | MMeTe | MMeTf | MItTb => Cp56TimeTag
    MEpTa => Cp24TimeTag
    MEpTb | MEpTc | MEpTd | MEpTe | MEpTf => Cp56TimeTag
    _ => NoTimeTag
  }
}

///|
/// Sum milliseconds since midnight, used by deterministic simulations.
pub fn milliseconds_since_midnight(
  hour : Int,
  minute : Int,
  second : Int,
  millisecond : Int,
) -> Result[Int, String] {
  if hour < 0 ||
    hour > 23 ||
    minute < 0 ||
    minute > 59 ||
    second < 0 ||
    second > 59 ||
    millisecond < 0 ||
    millisecond > 999 {
    Err("time of day component is outside its range")
  } else {
    Ok(((hour * 60 + minute) * 60 + second) * 1000 + millisecond)
  }
}

///|
/// Split milliseconds since midnight into hour, minute, second and remainder.
pub fn split_milliseconds_since_midnight(
  value : Int,
) -> Result[(Int, Int, Int, Int), String] {
  if value < 0 || value >= 24 * 60 * 60 * 1000 {
    Err("time of day must fit a single day")
  } else {
    let hour = value / 3600000
    let minute = value % 3600000 / 60000
    let second = value % 60000 / 1000
    let millisecond = value % 1000
    Ok((hour, minute, second, millisecond))
  }
}

///|
/// A tagged union used by event stores and application services.
pub enum TimeTag {
  Short(Cp24Time)
  Long(Cp56Time)
} derive(Eq, Debug)

///|
pub fn TimeTag::kind(self : TimeTag) -> TimeTagKind {
  match self {
    Short(_) => Cp24TimeTag
    Long(_) => Cp56TimeTag
  }
}

///|
pub fn TimeTag::width(self : TimeTag) -> Int {
  self.kind().width()
}

///|
pub fn TimeTag::to_array(self : TimeTag) -> Array[Byte] {
  match self {
    Short(value) => value.to_array()
    Long(value) => value.to_array()
  }
}

///|
/// Decode the selected tag precision from a byte sequence.
pub fn decode_time_tag(
  kind : TimeTagKind,
  data : Bytes,
  offset? : Int = 0,
) -> Result[TimeTag, String] {
  match kind {
    NoTimeTag => Err("a time tag is not present")
    Cp24TimeTag =>
      Cp24Time::from_bytes(data, offset~).map(value => Short(value))
    Cp56TimeTag => Cp56Time::from_bytes(data, offset~).map(value => Long(value))
  }
}

///|
pub fn encode_time_tag(tag : TimeTag) -> Bytes {
  Bytes::from_array(tag.to_array())
}

///|
/// Return the number of days in a year.
pub fn days_in_year(year : Int) -> Int {
  if is_leap_year(year) {
    366
  } else {
    365
  }
}

///|
/// Convert a month/day pair to a one-based ordinal day.
pub fn ordinal_day(year : Int, month : Int, day : Int) -> Result[Int, String] {
  match days_in_month(year, month) {
    None => Err("month must be between 1 and 12")
    Some(max_day) =>
      if day < 1 || day > max_day {
        Err("day is outside the selected month")
      } else {
        let mut total = 0
        for current in 1..<month {
          total += days_in_month(year, current).unwrap()
        }
        Ok(total + day)
      }
  }
}

///|
/// A deterministic date-time ordering key.
pub fn Cp56Time::ordering_key(self : Cp56Time) -> Int {
  let day = ordinal_day(self.calendar_year(), self.month, self.day).unwrap()
  day * 86400000 + self.hour * 3600000 + self.minute * 60000 + self.millisecond
}

///|
pub fn time_tag_examples() -> Array[TimeTag] {
  [
    Short(Cp24Time::new(0, 0).unwrap()),
    Long(Cp56Time::new(26, 8, 19, 12, 30, 45000, weekday=3).unwrap()),
  ]
}
