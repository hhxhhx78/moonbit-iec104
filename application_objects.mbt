///|
/// Values carried by standard IEC 104 information objects.
pub enum ApplicationValue {
  SinglePointValue(SinglePointValue)
  DoublePointValue(DoublePointValue)
  StepPositionValue(StepPositionValue)
  BitStringValue(UInt)
  NormalizedMeasurement(NormalizedValue)
  ScaledMeasurement(ScaledValue)
  ShortFloatMeasurement(ShortFloatValue)
  BinaryCounterMeasurement(BinaryCounterValue)
  SingleCommand(Bool, Int)
  DoubleCommand(Int, Int)
  RegulatingStepCommand(Int, Int)
  NormalizedSetPoint(Int, Int)
  ScaledSetPoint(Int, Int)
  ShortFloatSetPoint(Float, Int)
  BitStringCommand(UInt)
  InterrogationCommand(Int)
  CounterInterrogationCommand(Int)
  ReadCommand
  ClockSyncCommand(Cp56Time)
  TestCommand(Int)
  ResetCommand(Int)
  DelayCommand(Int)
  EndOfInitialization(Int)
  RawValue(Bytes)
} derive(Eq, Debug)

///|
/// An address-qualified application object with an optional time tag.
pub struct ApplicationObject {
  address : InformationAddress
  type_id : ApplicationType
  value : ApplicationValue
  time_tag : TimeTag?
} derive(Eq, Debug)

///|
fn make_application_object(
  address : InformationAddress,
  value : ApplicationValue,
  time_tag : TimeTag?,
) -> Result[ApplicationObject, String] {
  let base_type = application_value_type(value)
  let type_id = match time_tag {
    Some(Short(_)) => timed_application_type(base_type, Cp24TimeTag)
    Some(Long(_)) => timed_application_type(base_type, Cp56TimeTag)
    None => base_type
  }
  let expected = time_tag_kind_for_type(type_id)
  match (expected, time_tag) {
    (NoTimeTag, Some(_)) => Err("application type does not accept a time tag")
    (Cp24TimeTag, Some(Short(_))) => Ok({ address, type_id, value, time_tag })
    (Cp56TimeTag, Some(Long(_))) => Ok({ address, type_id, value, time_tag })
    (NoTimeTag, None) => Ok({ address, type_id, value, time_tag })
    (_, None) => Err("time-tagged application type requires a time tag")
    _ => Err("time tag precision does not match application type")
  }
}

///|
/// Construct an application object and optionally attach its standard time tag.
pub fn ApplicationObject::new(
  address : InformationAddress,
  value : ApplicationValue,
  time_tag? : TimeTag,
) -> Result[ApplicationObject, String] {
  make_application_object(address, value, time_tag)
}

///|
pub fn ApplicationObject::address(
  self : ApplicationObject,
) -> InformationAddress {
  self.address
}

///|
pub fn ApplicationObject::type_id(self : ApplicationObject) -> ApplicationType {
  self.type_id
}

///|
pub fn ApplicationObject::value(self : ApplicationObject) -> ApplicationValue {
  self.value
}

///|
pub fn ApplicationObject::time_tag(self : ApplicationObject) -> TimeTag? {
  self.time_tag
}

///|
pub fn ApplicationObject::is_command(self : ApplicationObject) -> Bool {
  self.type_id.is_control()
}

///|
pub fn ApplicationObject::is_measurement(self : ApplicationObject) -> Bool {
  self.type_id.is_monitoring()
}

///|
pub fn application_value_type(value : ApplicationValue) -> ApplicationType {
  match value {
    SinglePointValue(_) => MSpNa
    DoublePointValue(_) => MDpNa
    StepPositionValue(_) => MStNa
    BitStringValue(_) => MBoNa
    NormalizedMeasurement(_) => MMeNa
    ScaledMeasurement(_) => MMeNb
    ShortFloatMeasurement(_) => MMeNc
    BinaryCounterMeasurement(_) => MItNa
    SingleCommand(_, _) => CScNa
    DoubleCommand(_, _) => CDcNa
    RegulatingStepCommand(_, _) => CRcNa
    NormalizedSetPoint(_, _) => CSeNa
    ScaledSetPoint(_, _) => CSeNb
    ShortFloatSetPoint(_, _) => CSeNc
    BitStringCommand(_) => CBoNa
    InterrogationCommand(_) => CIcNa
    CounterInterrogationCommand(_) => CCiNa
    ReadCommand => CRdNa
    ClockSyncCommand(_) => CCsNa
    TestCommand(_) => CTsNa
    ResetCommand(_) => CRpNa
    DelayCommand(_) => CRpNa
    EndOfInitialization(_) => MEiNa
    RawValue(_) => UnknownType(0)
  }
}

///|
pub fn application_value_width(value : ApplicationValue) -> Int {
  match value {
    SinglePointValue(_) => 1
    DoublePointValue(_) => 1
    StepPositionValue(_) => 2
    BitStringValue(_) => 5
    NormalizedMeasurement(_) => 3
    ScaledMeasurement(_) => 3
    ShortFloatMeasurement(_) => 5
    BinaryCounterMeasurement(_) => 5
    SingleCommand(_, _) => 1
    DoubleCommand(_, _) => 1
    RegulatingStepCommand(_, _) => 1
    NormalizedSetPoint(_, _) => 2
    ScaledSetPoint(_, _) => 2
    ShortFloatSetPoint(_, _) => 4
    BitStringCommand(_) => 4
    InterrogationCommand(_) => 1
    CounterInterrogationCommand(_) => 1
    ReadCommand => 0
    ClockSyncCommand(_) => 7
    TestCommand(_) => 2
    ResetCommand(_) => 1
    DelayCommand(_) => 2
    EndOfInitialization(_) => 1
    RawValue(value) => value.length()
  }
}

///|
pub fn single_point_object(
  address : InformationAddress,
  state : Bool,
  quality? : StatusQuality = StatusQuality::clear(),
  time_tag? : TimeTag,
) -> Result[ApplicationObject, String] {
  make_application_object(
    address,
    SinglePointValue(SinglePointValue::new(state, quality~)),
    time_tag,
  )
}

///|
pub fn double_point_object(
  address : InformationAddress,
  state : Int,
  quality? : StatusQuality = StatusQuality::clear(),
  time_tag? : TimeTag,
) -> Result[ApplicationObject, String] {
  match DoublePointValue::new(state, quality~) {
    Ok(value) =>
      make_application_object(address, DoublePointValue(value), time_tag)
    Err(error) => Err(error)
  }
}

///|
pub fn step_position_object(
  address : InformationAddress,
  position : Int,
  transient? : Bool = false,
  quality? : StatusQuality = StatusQuality::clear(),
  time_tag? : TimeTag,
) -> Result[ApplicationObject, String] {
  match StepPositionValue::new(position, transient~, quality~) {
    Ok(value) =>
      make_application_object(address, StepPositionValue(value), time_tag)
    Err(error) => Err(error)
  }
}

///|
pub fn bit_string_object(
  address : InformationAddress,
  value : UInt,
  time_tag? : TimeTag,
) -> Result[ApplicationObject, String] {
  make_application_object(address, BitStringValue(value), time_tag)
}

///|
pub fn normalized_object(
  address : InformationAddress,
  value : Int,
  quality? : QualityDescriptor = QualityDescriptor::clear(),
  time_tag? : TimeTag,
) -> Result[ApplicationObject, String] {
  match NormalizedValue::new(value, quality~) {
    Ok(measurement) =>
      make_application_object(
        address,
        NormalizedMeasurement(measurement),
        time_tag,
      )
    Err(error) => Err(error)
  }
}

///|
pub fn scaled_object(
  address : InformationAddress,
  value : Int,
  quality? : QualityDescriptor = QualityDescriptor::clear(),
  time_tag? : TimeTag,
) -> Result[ApplicationObject, String] {
  match ScaledValue::new(value, quality~) {
    Ok(measurement) =>
      make_application_object(address, ScaledMeasurement(measurement), time_tag)
    Err(error) => Err(error)
  }
}

///|
pub fn short_float_object(
  address : InformationAddress,
  value : Float,
  quality? : QualityDescriptor = QualityDescriptor::clear(),
  time_tag? : TimeTag,
) -> Result[ApplicationObject, String] {
  make_application_object(
    address,
    ShortFloatMeasurement(ShortFloatValue::new(value, quality~)),
    time_tag,
  )
}

///|
pub fn binary_counter_object(
  address : InformationAddress,
  value : UInt,
  sequence? : Int = 0,
  time_tag? : TimeTag,
) -> Result[ApplicationObject, String] {
  match BinaryCounterValue::new(value, sequence~) {
    Ok(measurement) =>
      make_application_object(
        address,
        BinaryCounterMeasurement(measurement),
        time_tag,
      )
    Err(error) => Err(error)
  }
}

///|
pub fn single_command_object(
  address : InformationAddress,
  state : Bool,
  qualifier : Int,
) -> Result[ApplicationObject, String] {
  if qualifier < 0 || qualifier > 255 {
    Err("single command qualifier must fit one byte")
  } else {
    ApplicationObject::new(address, SingleCommand(state, qualifier))
  }
}

///|
pub fn double_command_object(
  address : InformationAddress,
  state : Int,
  qualifier : Int,
) -> Result[ApplicationObject, String] {
  if state < 0 || state > 3 {
    Err("double command state must fit two bits")
  } else if qualifier < 0 || qualifier > 255 {
    Err("double command qualifier must fit one byte")
  } else {
    ApplicationObject::new(address, DoubleCommand(state, qualifier))
  }
}

///|
pub fn regulating_step_command_object(
  address : InformationAddress,
  step : Int,
  qualifier : Int,
) -> Result[ApplicationObject, String] {
  if step < -64 || step > 63 {
    Err("regulating step must fit signed seven bits")
  } else if qualifier < 0 || qualifier > 255 {
    Err("regulating step qualifier must fit one byte")
  } else {
    ApplicationObject::new(address, RegulatingStepCommand(step, qualifier))
  }
}

///|
pub fn normalized_set_point_object(
  address : InformationAddress,
  value : Int,
  qualifier : Int,
) -> Result[ApplicationObject, String] {
  if value < -32768 || value > 32767 {
    Err("normalized set point must fit signed 16 bits")
  } else if qualifier < 0 || qualifier > 255 {
    Err("set point qualifier must fit one byte")
  } else {
    ApplicationObject::new(address, NormalizedSetPoint(value, qualifier))
  }
}

///|
pub fn scaled_set_point_object(
  address : InformationAddress,
  value : Int,
  qualifier : Int,
) -> Result[ApplicationObject, String] {
  if value < -32768 || value > 32767 {
    Err("scaled set point must fit signed 16 bits")
  } else if qualifier < 0 || qualifier > 255 {
    Err("set point qualifier must fit one byte")
  } else {
    ApplicationObject::new(address, ScaledSetPoint(value, qualifier))
  }
}

///|
pub fn short_float_set_point_object(
  address : InformationAddress,
  value : Float,
  qualifier : Int,
) -> Result[ApplicationObject, String] {
  if qualifier < 0 || qualifier > 255 {
    Err("set point qualifier must fit one byte")
  } else {
    ApplicationObject::new(address, ShortFloatSetPoint(value, qualifier))
  }
}

///|
pub fn interrogation_object(
  address : InformationAddress,
  qualifier : Int,
) -> Result[ApplicationObject, String] {
  if qualifier < 0 || qualifier > 255 {
    Err("interrogation qualifier must fit one byte")
  } else {
    ApplicationObject::new(address, InterrogationCommand(qualifier))
  }
}

///|
pub fn counter_interrogation_object(
  address : InformationAddress,
  qualifier : Int,
) -> Result[ApplicationObject, String] {
  if qualifier < 0 || qualifier > 255 {
    Err("counter interrogation qualifier must fit one byte")
  } else {
    ApplicationObject::new(address, CounterInterrogationCommand(qualifier))
  }
}

///|
pub fn read_object(
  address : InformationAddress,
) -> Result[ApplicationObject, String] {
  ApplicationObject::new(address, ReadCommand)
}

///|
pub fn clock_sync_object(
  address : InformationAddress,
  value : Cp56Time,
) -> Result[ApplicationObject, String] {
  ApplicationObject::new(address, ClockSyncCommand(value))
}

///|
pub fn test_command_object(
  address : InformationAddress,
  value : Int,
) -> Result[ApplicationObject, String] {
  if value < 0 || value > 65535 {
    Err("test command value must fit 16 bits")
  } else {
    ApplicationObject::new(address, TestCommand(value))
  }
}

///|
pub fn reset_command_object(
  address : InformationAddress,
  value : Int,
) -> Result[ApplicationObject, String] {
  if value < 0 || value > 255 {
    Err("reset command value must fit one byte")
  } else {
    ApplicationObject::new(address, ResetCommand(value))
  }
}

///|
pub fn end_of_initialization_object(
  address : InformationAddress,
  value : Int,
) -> Result[ApplicationObject, String] {
  if value < 0 || value > 255 {
    Err("end-of-initialization value must fit one byte")
  } else {
    ApplicationObject::new(address, EndOfInitialization(value))
  }
}

///|
fn push_object_u16(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xff).to_byte())
  out.push(((value >> 8) & 0xff).to_byte())
}

///|
fn push_object_u32(out : Array[Byte], value : UInt) -> Unit {
  out.push((value & 0xffU).to_byte())
  out.push(((value >> 8) & 0xffU).to_byte())
  out.push(((value >> 16) & 0xffU).to_byte())
  out.push(((value >> 24) & 0xffU).to_byte())
}

///|
fn push_object_address(out : Array[Byte], address : InformationAddress) -> Unit {
  out.push(address.low().to_byte())
  out.push(address.middle().to_byte())
  out.push(address.high().to_byte())
}

///|
/// Encode an IOA-qualified object without the ASDU header.
pub fn encode_application_object(object : ApplicationObject) -> Bytes {
  let out : Array[Byte] = []
  push_object_address(out, object.address)
  match object.value {
    SinglePointValue(value) => out.push(value.to_byte().to_byte())
    DoublePointValue(value) => out.push(value.to_byte().to_byte())
    StepPositionValue(value) =>
      for byte in value.to_array() {
        out.push(byte)
      }
    BitStringValue(value) => push_object_u32(out, value)
    NormalizedMeasurement(value) =>
      for byte in value.to_array() {
        out.push(byte)
      }
    ScaledMeasurement(value) =>
      for byte in value.to_array() {
        out.push(byte)
      }
    ShortFloatMeasurement(value) => {
      push_object_u32(out, value.value().reinterpret_as_uint())
      out.push(value.quality().to_byte().to_byte())
    }
    BinaryCounterMeasurement(value) => {
      push_object_u32(out, value.value())
      out.push(value.flags().to_byte())
    }
    SingleCommand(state, qualifier) =>
      out.push(((if state { 1 } else { 0 }) | (qualifier & 0xf0)).to_byte())
    DoubleCommand(state, qualifier) =>
      out.push(((state & 3) | (qualifier & 0xf0)).to_byte())
    RegulatingStepCommand(step, qualifier) => {
      let encoded = if step < 0 { step + 128 } else { step }
      out.push(((encoded & 0x7f) | (qualifier & 0xf0)).to_byte())
    }
    NormalizedSetPoint(value, qualifier) => {
      let raw = if value < 0 { value + 65536 } else { value }
      push_object_u16(out, raw)
      out.push(qualifier.to_byte())
    }
    ScaledSetPoint(value, qualifier) => {
      let raw = if value < 0 { value + 65536 } else { value }
      push_object_u16(out, raw)
      out.push(qualifier.to_byte())
    }
    ShortFloatSetPoint(value, qualifier) => {
      push_object_u32(out, value.reinterpret_as_uint())
      out.push(qualifier.to_byte())
    }
    BitStringCommand(value) => push_object_u32(out, value)
    InterrogationCommand(qualifier) => out.push(qualifier.to_byte())
    CounterInterrogationCommand(qualifier) => out.push(qualifier.to_byte())
    ReadCommand => ()
    ClockSyncCommand(value) =>
      for byte in value.to_array() {
        out.push(byte)
      }
    TestCommand(value) => push_object_u16(out, value)
    ResetCommand(value) => out.push(value.to_byte())
    DelayCommand(value) => push_object_u16(out, value)
    EndOfInitialization(value) => out.push(value.to_byte())
    RawValue(value) =>
      for byte in value {
        out.push(byte)
      }
  }
  match object.time_tag {
    Some(tag) =>
      for byte in tag.to_array() {
        out.push(byte)
      }
    None => ()
  }
  Bytes::from_array(out)
}

///|
/// Return a type-tagged object as a stable compact summary tuple.
pub fn ApplicationObject::summary(
  self : ApplicationObject,
) -> (Int, Int, Int, Bool) {
  (
    self.type_id.number(),
    self.address.number(),
    application_value_width(self.value),
    self.time_tag is Some(_),
  )
}

///|
/// Validate an application object before placing it in an ASDU.
pub fn ApplicationObject::validate(
  self : ApplicationObject,
) -> Result[Unit, Diagnostic] {
  if self.address.number() < 0 || self.address.number() > 0xffffff {
    Err(Diagnostic::new(InvalidAddress, "object address is outside 24 bits"))
  } else if self.type_id is UnknownType(_) {
    Err(
      Diagnostic::new(InvalidType, "unknown application type cannot be encoded"),
    )
  } else {
    Ok(())
  }
}

///|
pub fn application_value_examples() -> Array[ApplicationValue] {
  [
    SinglePointValue(SinglePointValue::new(true)),
    DoublePointValue(DoublePointValue::new(1).unwrap()),
    StepPositionValue(StepPositionValue::new(-3).unwrap()),
    BitStringValue(0x1234U),
    NormalizedMeasurement(NormalizedValue::new(120).unwrap()),
    ScaledMeasurement(ScaledValue::new(-20).unwrap()),
    ShortFloatMeasurement(ShortFloatValue::new(2.5)),
    BinaryCounterMeasurement(BinaryCounterValue::new(42U).unwrap()),
    SingleCommand(true, 1),
    DoubleCommand(2, 1),
    RegulatingStepCommand(-1, 1),
    NormalizedSetPoint(2, 1),
    ScaledSetPoint(3, 1),
    ShortFloatSetPoint(4.0, 1),
    BitStringCommand(0U),
    InterrogationCommand(20),
    CounterInterrogationCommand(5),
    ReadCommand,
    ClockSyncCommand(Cp56Time::new(26, 1, 1, 0, 0, 0).unwrap()),
    TestCommand(0),
    ResetCommand(1),
    DelayCommand(10),
    EndOfInitialization(0),
    RawValue(b"raw"),
  ]
}
