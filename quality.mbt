///|
/// Quality descriptor shared by status and measurement objects.
pub struct QualityDescriptor {
  overflow : Bool
  blocked : Bool
  substituted : Bool
  not_topical : Bool
  invalid : Bool
} derive(Eq, Debug)

///|
pub fn QualityDescriptor::clear() -> QualityDescriptor {
  {
    overflow: false,
    blocked: false,
    substituted: false,
    not_topical: false,
    invalid: false,
  }
}

///|
/// Decode the low byte of a QDS value.
pub fn QualityDescriptor::from_byte(
  value : Int,
) -> Result[QualityDescriptor, String] {
  if value < 0 || value > 255 {
    Err("quality descriptor must fit one byte")
  } else {
    Ok({
      overflow: (value & 1) != 0,
      blocked: (value & 0x10) != 0,
      substituted: (value & 0x20) != 0,
      not_topical: (value & 0x40) != 0,
      invalid: (value & 0x80) != 0,
    })
  }
}

///|
pub fn QualityDescriptor::to_byte(self : QualityDescriptor) -> Int {
  (if self.overflow { 1 } else { 0 }) |
  (if self.blocked { 0x10 } else { 0 }) |
  (if self.substituted { 0x20 } else { 0 }) |
  (if self.not_topical { 0x40 } else { 0 }) |
  (if self.invalid { 0x80 } else { 0 })
}

///|
pub fn QualityDescriptor::with_overflow(
  self : QualityDescriptor,
  value : Bool,
) -> QualityDescriptor {
  {
    overflow: value,
    blocked: self.blocked,
    substituted: self.substituted,
    not_topical: self.not_topical,
    invalid: self.invalid,
  }
}

///|
pub fn QualityDescriptor::with_blocked(
  self : QualityDescriptor,
  value : Bool,
) -> QualityDescriptor {
  {
    overflow: self.overflow,
    blocked: value,
    substituted: self.substituted,
    not_topical: self.not_topical,
    invalid: self.invalid,
  }
}

///|
pub fn QualityDescriptor::with_substituted(
  self : QualityDescriptor,
  value : Bool,
) -> QualityDescriptor {
  {
    overflow: self.overflow,
    blocked: self.blocked,
    substituted: value,
    not_topical: self.not_topical,
    invalid: self.invalid,
  }
}

///|
pub fn QualityDescriptor::with_not_topical(
  self : QualityDescriptor,
  value : Bool,
) -> QualityDescriptor {
  {
    overflow: self.overflow,
    blocked: self.blocked,
    substituted: self.substituted,
    not_topical: value,
    invalid: self.invalid,
  }
}

///|
pub fn QualityDescriptor::with_invalid(
  self : QualityDescriptor,
  value : Bool,
) -> QualityDescriptor {
  {
    overflow: self.overflow,
    blocked: self.blocked,
    substituted: self.substituted,
    not_topical: self.not_topical,
    invalid: value,
  }
}

///|
pub fn QualityDescriptor::is_usable(self : QualityDescriptor) -> Bool {
  !self.invalid && !self.blocked
}

///|
pub fn QualityDescriptor::has_status_change(self : QualityDescriptor) -> Bool {
  self.substituted || self.not_topical || self.invalid
}

///|
pub fn QualityDescriptor::flags(self : QualityDescriptor) -> Array[String] {
  let flags : Array[String] = []
  if self.overflow {
    flags.push("overflow")
  }
  if self.blocked {
    flags.push("blocked")
  }
  if self.substituted {
    flags.push("substituted")
  }
  if self.not_topical {
    flags.push("not-topical")
  }
  if self.invalid {
    flags.push("invalid")
  }
  flags
}

///|
/// Quality descriptor for single and double point status values.
pub struct StatusQuality {
  blocked : Bool
  substituted : Bool
  not_topical : Bool
  invalid : Bool
} derive(Eq, Debug)

///|
pub fn StatusQuality::clear() -> StatusQuality {
  { blocked: false, substituted: false, not_topical: false, invalid: false }
}

///|
pub fn StatusQuality::from_byte(value : Int) -> Result[StatusQuality, String] {
  if value < 0 || value > 255 {
    Err("status quality must fit one byte")
  } else {
    Ok({
      blocked: (value & 0x10) != 0,
      substituted: (value & 0x20) != 0,
      not_topical: (value & 0x40) != 0,
      invalid: (value & 0x80) != 0,
    })
  }
}

///|
pub fn StatusQuality::to_byte(self : StatusQuality) -> Int {
  (if self.blocked { 0x10 } else { 0 }) |
  (if self.substituted { 0x20 } else { 0 }) |
  (if self.not_topical { 0x40 } else { 0 }) |
  (if self.invalid { 0x80 } else { 0 })
}

///|
pub fn StatusQuality::as_measurement(self : StatusQuality) -> QualityDescriptor {
  {
    overflow: false,
    blocked: self.blocked,
    substituted: self.substituted,
    not_topical: self.not_topical,
    invalid: self.invalid,
  }
}

///|
pub fn StatusQuality::is_usable(self : StatusQuality) -> Bool {
  !self.invalid && !self.blocked
}

///|
/// Single point information value, including its QDS.
pub struct SinglePointValue {
  state : Bool
  quality : StatusQuality
} derive(Eq, Debug)

///|
pub fn SinglePointValue::new(
  state : Bool,
  quality? : StatusQuality = StatusQuality::clear(),
) -> SinglePointValue {
  { state, quality }
}

///|
pub fn SinglePointValue::state(self : SinglePointValue) -> Bool {
  self.state
}

///|
pub fn SinglePointValue::quality(self : SinglePointValue) -> StatusQuality {
  self.quality
}

///|
pub fn SinglePointValue::to_byte(self : SinglePointValue) -> Int {
  (if self.state { 1 } else { 0 }) | self.quality.to_byte()
}

///|
pub fn SinglePointValue::from_byte(
  value : Int,
) -> Result[SinglePointValue, String] {
  if value < 0 || value > 255 {
    Err("single point value must fit one byte")
  } else {
    match StatusQuality::from_byte(value) {
      Ok(quality) => Ok({ state: (value & 1) != 0, quality })
      Err(error) => Err(error)
    }
  }
}

///|
/// Double point information value. IEC 104 reserves state value 0 and 3.
pub struct DoublePointValue {
  state : Int
  quality : StatusQuality
} derive(Eq, Debug)

///|
pub fn DoublePointValue::new(
  state : Int,
  quality? : StatusQuality = StatusQuality::clear(),
) -> Result[DoublePointValue, String] {
  if state < 0 || state > 3 {
    Err("double point state must fit two bits")
  } else {
    Ok({ state, quality })
  }
}

///|
pub fn DoublePointValue::state(self : DoublePointValue) -> Int {
  self.state
}

///|
pub fn DoublePointValue::quality(self : DoublePointValue) -> StatusQuality {
  self.quality
}

///|
pub fn DoublePointValue::to_byte(self : DoublePointValue) -> Int {
  (self.state & 3) | self.quality.to_byte()
}

///|
pub fn DoublePointValue::from_byte(
  value : Int,
) -> Result[DoublePointValue, String] {
  if value < 0 || value > 255 {
    Err("double point value must fit one byte")
  } else {
    match StatusQuality::from_byte(value) {
      Ok(quality) => Ok({ state: value & 3, quality })
      Err(error) => Err(error)
    }
  }
}

///|
/// Step position value with a signed seven-bit position and transient flag.
pub struct StepPositionValue {
  position : Int
  transient : Bool
  quality : StatusQuality
} derive(Eq, Debug)

///|
pub fn StepPositionValue::new(
  position : Int,
  transient? : Bool = false,
  quality? : StatusQuality = StatusQuality::clear(),
) -> Result[StepPositionValue, String] {
  if position < -64 || position > 63 {
    Err("step position must fit signed seven bits")
  } else {
    Ok({ position, transient, quality })
  }
}

///|
pub fn StepPositionValue::position(self : StepPositionValue) -> Int {
  self.position
}

///|
pub fn StepPositionValue::quality(self : StepPositionValue) -> StatusQuality {
  self.quality
}

///|
pub fn StepPositionValue::to_array(self : StepPositionValue) -> Array[Byte] {
  let encoded = if self.position < 0 {
    self.position + 128
  } else {
    self.position
  }
  [
    encoded.to_byte(),
    ((if self.transient { 1 } else { 0 }) | self.quality.to_byte()).to_byte(),
  ]
}

///|
/// Normalized signed 16-bit measurement.
pub struct NormalizedValue {
  value : Int
  quality : QualityDescriptor
} derive(Eq, Debug)

///|
pub fn NormalizedValue::new(
  value : Int,
  quality? : QualityDescriptor = QualityDescriptor::clear(),
) -> Result[NormalizedValue, String] {
  if value < -32768 || value > 32767 {
    Err("normalized value must fit signed 16 bits")
  } else {
    Ok({ value, quality })
  }
}

///|
pub fn NormalizedValue::value(self : NormalizedValue) -> Int {
  self.value
}

///|
pub fn NormalizedValue::quality(self : NormalizedValue) -> QualityDescriptor {
  self.quality
}

///|
pub fn NormalizedValue::raw_unsigned(self : NormalizedValue) -> Int {
  if self.value < 0 {
    self.value + 65536
  } else {
    self.value
  }
}

///|
pub fn NormalizedValue::to_array(self : NormalizedValue) -> Array[Byte] {
  [
    (self.raw_unsigned() & 0xff).to_byte(),
    ((self.raw_unsigned() >> 8) & 0xff).to_byte(),
    self.quality.to_byte().to_byte(),
  ]
}

///|
/// Signed 16-bit scaled measurement.
pub struct ScaledValue {
  value : Int
  quality : QualityDescriptor
} derive(Eq, Debug)

///|
pub fn ScaledValue::new(
  value : Int,
  quality? : QualityDescriptor = QualityDescriptor::clear(),
) -> Result[ScaledValue, String] {
  if value < -32768 || value > 32767 {
    Err("scaled value must fit signed 16 bits")
  } else {
    Ok({ value, quality })
  }
}

///|
pub fn ScaledValue::value(self : ScaledValue) -> Int {
  self.value
}

///|
pub fn ScaledValue::quality(self : ScaledValue) -> QualityDescriptor {
  self.quality
}

///|
pub fn ScaledValue::to_array(self : ScaledValue) -> Array[Byte] {
  let raw = if self.value < 0 { self.value + 65536 } else { self.value }
  [
    (raw & 0xff).to_byte(),
    ((raw >> 8) & 0xff).to_byte(),
    self.quality.to_byte().to_byte(),
  ]
}

///|
/// IEEE-754 short floating point measurement.
pub struct ShortFloatValue {
  value : Float
  quality : QualityDescriptor
} derive(Eq, Debug)

///|
pub fn ShortFloatValue::new(
  value : Float,
  quality? : QualityDescriptor = QualityDescriptor::clear(),
) -> ShortFloatValue {
  { value, quality }
}

///|
pub fn ShortFloatValue::value(self : ShortFloatValue) -> Float {
  self.value
}

///|
pub fn ShortFloatValue::quality(self : ShortFloatValue) -> QualityDescriptor {
  self.quality
}

///|
/// 32-bit binary counter value with sequence and overflow flags.
pub struct BinaryCounterValue {
  value : UInt
  sequence : Int
  carry : Bool
  adjusted : Bool
  invalid : Bool
} derive(Eq, Debug)

///|
pub fn BinaryCounterValue::new(
  value : UInt,
  sequence? : Int = 0,
  carry? : Bool = false,
  adjusted? : Bool = false,
  invalid? : Bool = false,
) -> Result[BinaryCounterValue, String] {
  if sequence < 0 || sequence > 31 {
    Err("binary counter sequence must fit five bits")
  } else {
    Ok({ value, sequence, carry, adjusted, invalid })
  }
}

///|
pub fn BinaryCounterValue::value(self : BinaryCounterValue) -> UInt {
  self.value
}

///|
pub fn BinaryCounterValue::sequence(self : BinaryCounterValue) -> Int {
  self.sequence
}

///|
pub fn BinaryCounterValue::flags(self : BinaryCounterValue) -> Int {
  self.sequence |
  (if self.carry { 0x20 } else { 0 }) |
  (if self.adjusted { 0x40 } else { 0 }) |
  (if self.invalid { 0x80 } else { 0 })
}

///|
/// Quality-preserving measurement classification used by point stores.
pub enum MeasurementState {
  Good
  Blocked
  Substituted
  NotTopical
  Invalid
} derive(Eq, Debug)

///|
pub fn measurement_state(quality : QualityDescriptor) -> MeasurementState {
  if quality.invalid {
    Invalid
  } else if quality.blocked {
    Blocked
  } else if quality.substituted {
    Substituted
  } else if quality.not_topical {
    NotTopical
  } else {
    Good
  }
}

///|
pub fn measurement_state_examples() -> Array[MeasurementState] {
  [Good, Blocked, Substituted, NotTopical, Invalid]
}

///|
/// Build a quality descriptor from a measurement state.
pub fn quality_for_state(state : MeasurementState) -> QualityDescriptor {
  match state {
    Good => QualityDescriptor::clear()
    Blocked => QualityDescriptor::clear().with_blocked(true)
    Substituted => QualityDescriptor::clear().with_substituted(true)
    NotTopical => QualityDescriptor::clear().with_not_topical(true)
    Invalid => QualityDescriptor::clear().with_invalid(true)
  }
}

///|
/// Return the signed value represented by a two-byte little-endian field.
pub fn decode_signed16(low : Int, high : Int) -> Result[Int, String] {
  if low < 0 || low > 255 || high < 0 || high > 255 {
    Err("signed value octets must fit one byte")
  } else {
    let raw = low | (high << 8)
    Ok(if raw >= 32768 { raw - 65536 } else { raw })
  }
}

///|
/// Encode a signed value into a little-endian two-byte field.
pub fn encode_signed16(value : Int) -> Result[Array[Byte], String] {
  if value < -32768 || value > 32767 {
    Err("signed value must fit 16 bits")
  } else {
    let raw = if value < 0 { value + 65536 } else { value }
    Ok([(raw & 0xff).to_byte(), ((raw >> 8) & 0xff).to_byte()])
  }
}

///|
/// Clamp a quality byte to the protocol's low eight bits.
pub fn normalize_quality(value : Int) -> Int {
  value & 0xff
}
