///|
/// A complete ASDU envelope with address-qualified application objects.
pub struct AsduEnvelope {
  type_id : ApplicationType
  sequence : Bool
  cause : CauseOfTransmission
  common_address : CommonAddress
  objects : Array[ApplicationObject]
} derive(Eq, Debug)

///|
/// Construct an ASDU envelope and check its object/type relationship.
pub fn AsduEnvelope::new(
  type_id : ApplicationType,
  sequence : Bool,
  cause : CauseOfTransmission,
  common_address : CommonAddress,
  objects : Array[ApplicationObject],
) -> Result[AsduEnvelope, Diagnostic] {
  if objects.length() > 127 {
    Err(
      Diagnostic::new(
        InvalidQualifier,
        "ASDU variable structure count exceeds 127",
      ),
    )
  } else if objects.is_empty() {
    Err(Diagnostic::new(InvalidType, "ASDU must contain at least one object"))
  } else {
    let mut index = 0
    let mut mismatch = false
    for object in objects {
      if object.type_id() != type_id {
        mismatch = true
      }
      if sequence &&
        index > 0 &&
        object.address().number() < objects[index - 1].address().number() {
        mismatch = true
      }
      index += 1
    }
    if mismatch {
      Err(
        Diagnostic::new(
          InvalidType,
          "ASDU object type or sequence order is inconsistent",
        ),
      )
    } else {
      Ok({ type_id, sequence, cause, common_address, objects })
    }
  }
}

///|
pub fn AsduEnvelope::type_id(self : AsduEnvelope) -> ApplicationType {
  self.type_id
}

///|
pub fn AsduEnvelope::sequence(self : AsduEnvelope) -> Bool {
  self.sequence
}

///|
pub fn AsduEnvelope::cause(self : AsduEnvelope) -> CauseOfTransmission {
  self.cause
}

///|
pub fn AsduEnvelope::common_address(self : AsduEnvelope) -> CommonAddress {
  self.common_address
}

///|
pub fn AsduEnvelope::objects(self : AsduEnvelope) -> Array[ApplicationObject] {
  self.objects.copy()
}

///|
pub fn AsduEnvelope::count(self : AsduEnvelope) -> Int {
  self.objects.length()
}

///|
fn extended_push_u16(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xff).to_byte())
  out.push(((value >> 8) & 0xff).to_byte())
}

///|
fn extended_push_address(out : Array[Byte], value : InformationAddress) -> Unit {
  out.push(value.low().to_byte())
  out.push(value.middle().to_byte())
  out.push(value.high().to_byte())
}

///|
fn extended_push_value(out : Array[Byte], value : ApplicationValue) -> Unit {
  match value {
    SinglePointValue(value) => out.push(value.to_byte().to_byte())
    DoublePointValue(value) => out.push(value.to_byte().to_byte())
    StepPositionValue(value) =>
      for byte in value.to_array() {
        out.push(byte)
      }
    BitStringValue(value) => {
      out.push((value & 0xffU).to_byte())
      out.push(((value >> 8) & 0xffU).to_byte())
      out.push(((value >> 16) & 0xffU).to_byte())
      out.push(((value >> 24) & 0xffU).to_byte())
    }
    NormalizedMeasurement(value) =>
      for byte in value.to_array() {
        out.push(byte)
      }
    ScaledMeasurement(value) =>
      for byte in value.to_array() {
        out.push(byte)
      }
    ShortFloatMeasurement(value) => {
      let raw = value.value().reinterpret_as_uint()
      out.push((raw & 0xffU).to_byte())
      out.push(((raw >> 8) & 0xffU).to_byte())
      out.push(((raw >> 16) & 0xffU).to_byte())
      out.push(((raw >> 24) & 0xffU).to_byte())
      out.push(value.quality().to_byte().to_byte())
    }
    BinaryCounterMeasurement(value) => {
      let raw = value.value()
      out.push((raw & 0xffU).to_byte())
      out.push(((raw >> 8) & 0xffU).to_byte())
      out.push(((raw >> 16) & 0xffU).to_byte())
      out.push(((raw >> 24) & 0xffU).to_byte())
      out.push(value.flags().to_byte())
    }
    SingleCommand(state, qualifier) =>
      out.push(((if state { 1 } else { 0 }) | qualifier).to_byte())
    DoubleCommand(state, qualifier) =>
      out.push(((state & 3) | qualifier).to_byte())
    RegulatingStepCommand(step, qualifier) => {
      let raw = if step < 0 { step + 128 } else { step }
      out.push(((raw & 0x7f) | qualifier).to_byte())
    }
    NormalizedSetPoint(value, qualifier) => {
      let raw = if value < 0 { value + 65536 } else { value }
      extended_push_u16(out, raw)
      out.push(qualifier.to_byte())
    }
    ScaledSetPoint(value, qualifier) => {
      let raw = if value < 0 { value + 65536 } else { value }
      extended_push_u16(out, raw)
      out.push(qualifier.to_byte())
    }
    ShortFloatSetPoint(value, qualifier) => {
      let raw = value.reinterpret_as_uint()
      out.push((raw & 0xffU).to_byte())
      out.push(((raw >> 8) & 0xffU).to_byte())
      out.push(((raw >> 16) & 0xffU).to_byte())
      out.push(((raw >> 24) & 0xffU).to_byte())
      out.push(qualifier.to_byte())
    }
    BitStringCommand(value) => {
      out.push((value & 0xffU).to_byte())
      out.push(((value >> 8) & 0xffU).to_byte())
      out.push(((value >> 16) & 0xffU).to_byte())
      out.push(((value >> 24) & 0xffU).to_byte())
    }
    InterrogationCommand(value) => out.push(value.to_byte())
    CounterInterrogationCommand(value) => out.push(value.to_byte())
    ReadCommand => ()
    ClockSyncCommand(value) =>
      for byte in value.to_array() {
        out.push(byte)
      }
    TestCommand(value) => extended_push_u16(out, value)
    ResetCommand(value) => out.push(value.to_byte())
    DelayCommand(value) => extended_push_u16(out, value)
    EndOfInitialization(value) => out.push(value.to_byte())
    RawValue(value) =>
      for byte in value {
        out.push(byte)
      }
  }
}

///|
fn extended_push_time_tag(out : Array[Byte], tag : TimeTag?) -> Unit {
  match tag {
    Some(value) =>
      for byte in value.to_array() {
        out.push(byte)
      }
    None => ()
  }
}

///|
fn timed_application_type(
  base : ApplicationType,
  kind : TimeTagKind,
) -> ApplicationType {
  match (kind, base) {
    (Cp24TimeTag, MSpNa) => MSpTa
    (Cp24TimeTag, MDpNa) => MDpTa
    (Cp24TimeTag, MStNa) => MStTa
    (Cp24TimeTag, MBoNa) => MBoTa
    (Cp24TimeTag, MMeNa) => MMeTa
    (Cp24TimeTag, MMeNb) => MMeTb
    (Cp24TimeTag, MMeNc) => MMeTc
    (Cp24TimeTag, MItNa) => MItTa
    (Cp56TimeTag, MSpNa) => MSpTb
    (Cp56TimeTag, MDpNa) => MDpTb
    (Cp56TimeTag, MStNa) => MStTb
    (Cp56TimeTag, MBoNa) => MBoTb
    (Cp56TimeTag, MMeNa) => MMeTd
    (Cp56TimeTag, MMeNb) => MMeTe
    (Cp56TimeTag, MMeNc) => MMeTf
    (Cp56TimeTag, MItNa) => MItTb
    (_, _) => base
  }
}

///|
fn object_base_type(type_id : ApplicationType) -> ApplicationType {
  match type_id {
    MSpTa | MSpTb => MSpNa
    MDpTa | MDpTb => MDpNa
    MStTa | MStTb => MStNa
    MBoTa | MBoTb => MBoNa
    MMeTa | MMeTd => MMeNa
    MMeTb | MMeTe => MMeNb
    MMeTc | MMeTf => MMeNc
    MItTa | MItTb => MItNa
    _ => type_id
  }
}

///|
fn make_cot_byte(cause : CauseOfTransmission) -> Int {
  cause.flags()
}

///|
/// Encode an address-qualified ASDU into its IEC 104 application payload.
pub fn encode_extended_asdu(
  envelope : AsduEnvelope,
) -> Result[Bytes, Diagnostic] {
  if envelope.objects.length() > 127 {
    return Err(
      Diagnostic::new(
        InvalidQualifier,
        "ASDU object count exceeds VSQ capacity",
      ),
    )
  }
  let out : Array[Byte] = [
    envelope.type_id.number().to_byte(),
    ((if envelope.sequence { 0x80 } else { 0 }) | envelope.objects.length()).to_byte(),
    make_cot_byte(envelope.cause).to_byte(),
    envelope.cause.originator().to_byte(),
    (envelope.common_address.number() & 0xff).to_byte(),
    ((envelope.common_address.number() >> 8) & 0xff).to_byte(),
  ]
  let mut index = 0
  for object in envelope.objects {
    match object.validate() {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    if !envelope.sequence || index == 0 {
      extended_push_address(out, object.address())
    }
    extended_push_value(out, object.value())
    extended_push_time_tag(out, object.time_tag())
    index += 1
  }
  Ok(Bytes::from_array(out))
}

///|
fn extended_read_u16(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() | (data[offset + 1].to_int() << 8)
}

///|
fn extended_read_u32(data : Bytes, offset : Int) -> UInt {
  data[offset].to_int().reinterpret_as_uint() |
  (data[offset + 1].to_int().reinterpret_as_uint() << 8) |
  (data[offset + 2].to_int().reinterpret_as_uint() << 16) |
  (data[offset + 3].to_int().reinterpret_as_uint() << 24)
}

///|
fn extended_error(
  kind : DiagnosticKind,
  message : String,
  offset : Int,
) -> Diagnostic {
  Diagnostic::new(kind, message, offset~)
}

///|
fn extended_read_address(
  data : Bytes,
  offset : Int,
) -> Result[InformationAddress, Diagnostic] {
  if offset < 0 || data.length() < offset + 3 {
    Err(
      extended_error(MalformedFrame, "ASDU object address is truncated", offset),
    )
  } else {
    match
      InformationAddress::from_octets(
        data[offset].to_int(),
        data[offset + 1].to_int(),
        data[offset + 2].to_int(),
      ) {
      Ok(address) => Ok(address)
      Err(message) => Err(extended_error(InvalidAddress, message, offset))
    }
  }
}

///|
fn extended_need(
  data : Bytes,
  offset : Int,
  width : Int,
) -> Result[Unit, Diagnostic] {
  if offset < 0 || width < 0 || data.length() < offset + width {
    Err(
      extended_error(
        MalformedFrame,
        "ASDU information object is truncated",
        offset,
      ),
    )
  } else {
    Ok(())
  }
}

///|
fn extended_read_value(
  type_id : ApplicationType,
  data : Bytes,
  offset : Int,
) -> Result[(ApplicationValue, Int), Diagnostic] {
  let base = object_base_type(type_id)
  match base {
    MSpNa => {
      match extended_need(data, offset, 1) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      match SinglePointValue::from_byte(data[offset].to_int()) {
        Ok(value) => Ok((SinglePointValue(value), 1))
        Err(message) => Err(extended_error(InvalidQualifier, message, offset))
      }
    }
    MDpNa => {
      match extended_need(data, offset, 1) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      match DoublePointValue::from_byte(data[offset].to_int()) {
        Ok(value) => Ok((DoublePointValue(value), 1))
        Err(message) => Err(extended_error(InvalidQualifier, message, offset))
      }
    }
    MStNa => {
      match extended_need(data, offset, 2) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      let position_raw = data[offset].to_int() & 0x7f
      let position = if position_raw >= 64 {
        position_raw - 128
      } else {
        position_raw
      }
      match StatusQuality::from_byte(data[offset + 1].to_int()) {
        Ok(quality) =>
          match
            StepPositionValue::new(
              position,
              transient=(data[offset] & b'\x80') != b'\x00',
              quality~,
            ) {
            Ok(value) => Ok((StepPositionValue(value), 2))
            Err(message) =>
              Err(extended_error(InvalidQualifier, message, offset))
          }
        Err(message) =>
          Err(extended_error(InvalidQualifier, message, offset + 1))
      }
    }
    MBoNa => {
      match extended_need(data, offset, 5) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      match QualityDescriptor::from_byte(data[offset + 4].to_int()) {
        Ok(_) => Ok((BitStringValue(extended_read_u32(data, offset)), 5))
        Err(message) =>
          Err(extended_error(InvalidQualifier, message, offset + 4))
      }
    }
    MMeNa => {
      match extended_need(data, offset, 3) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      match decode_signed16(data[offset].to_int(), data[offset + 1].to_int()) {
        Err(message) => Err(extended_error(InvalidQualifier, message, offset))
        Ok(value) =>
          match QualityDescriptor::from_byte(data[offset + 2].to_int()) {
            Err(message) =>
              Err(extended_error(InvalidQualifier, message, offset + 2))
            Ok(quality) =>
              match NormalizedValue::new(value, quality~) {
                Ok(measurement) => Ok((NormalizedMeasurement(measurement), 3))
                Err(message) =>
                  Err(extended_error(InvalidQualifier, message, offset))
              }
          }
      }
    }
    MMeNb => {
      match extended_need(data, offset, 3) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      match decode_signed16(data[offset].to_int(), data[offset + 1].to_int()) {
        Err(message) => Err(extended_error(InvalidQualifier, message, offset))
        Ok(value) =>
          match QualityDescriptor::from_byte(data[offset + 2].to_int()) {
            Err(message) =>
              Err(extended_error(InvalidQualifier, message, offset + 2))
            Ok(quality) =>
              match ScaledValue::new(value, quality~) {
                Ok(measurement) => Ok((ScaledMeasurement(measurement), 3))
                Err(message) =>
                  Err(extended_error(InvalidQualifier, message, offset))
              }
          }
      }
    }
    MMeNc => {
      match extended_need(data, offset, 5) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      match QualityDescriptor::from_byte(data[offset + 4].to_int()) {
        Err(message) =>
          Err(extended_error(InvalidQualifier, message, offset + 4))
        Ok(quality) =>
          Ok(
            (
              ShortFloatMeasurement(
                ShortFloatValue::new(
                  Float::reinterpret_from_uint(extended_read_u32(data, offset)),
                  quality~,
                ),
              ),
              5,
            ),
          )
      }
    }
    MItNa => {
      match extended_need(data, offset, 5) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      let flags = data[offset + 4].to_int()
      match
        BinaryCounterValue::new(
          extended_read_u32(data, offset),
          sequence=flags & 0x1f,
          carry=(flags & 0x20) != 0,
          adjusted=(flags & 0x40) != 0,
          invalid=(flags & 0x80) != 0,
        ) {
        Ok(value) => Ok((BinaryCounterMeasurement(value), 5))
        Err(message) =>
          Err(extended_error(InvalidQualifier, message, offset + 4))
      }
    }
    MMeNd => {
      match extended_need(data, offset, 2) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      match decode_signed16(data[offset].to_int(), data[offset + 1].to_int()) {
        Ok(value) =>
          match NormalizedValue::new(value) {
            Ok(measurement) => Ok((NormalizedMeasurement(measurement), 2))
            Err(message) =>
              Err(extended_error(InvalidQualifier, message, offset))
          }
        Err(message) => Err(extended_error(InvalidQualifier, message, offset))
      }
    }
    CScNa => {
      match extended_need(data, offset, 1) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      Ok(
        (
          SingleCommand(
            (data[offset] & b'\x01') != b'\x00',
            data[offset].to_int() & 0xf0,
          ),
          1,
        ),
      )
    }
    CDcNa => {
      match extended_need(data, offset, 1) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      Ok(
        (
          DoubleCommand(data[offset].to_int() & 3, data[offset].to_int() & 0xf0),
          1,
        ),
      )
    }
    CRcNa => {
      match extended_need(data, offset, 1) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      let raw = data[offset].to_int() & 0x7f
      let step = if raw >= 64 { raw - 128 } else { raw }
      Ok((RegulatingStepCommand(step, data[offset].to_int() & 0xf0), 1))
    }
    CSeNa => {
      match extended_need(data, offset, 3) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      match decode_signed16(data[offset].to_int(), data[offset + 1].to_int()) {
        Ok(value) =>
          Ok((NormalizedSetPoint(value, data[offset + 2].to_int()), 3))
        Err(message) => Err(extended_error(InvalidQualifier, message, offset))
      }
    }
    CSeNb => {
      match extended_need(data, offset, 3) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      match decode_signed16(data[offset].to_int(), data[offset + 1].to_int()) {
        Ok(value) => Ok((ScaledSetPoint(value, data[offset + 2].to_int()), 3))
        Err(message) => Err(extended_error(InvalidQualifier, message, offset))
      }
    }
    CSeNc => {
      match extended_need(data, offset, 5) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      Ok(
        (
          ShortFloatSetPoint(
            Float::reinterpret_from_uint(extended_read_u32(data, offset)),
            data[offset + 4].to_int(),
          ),
          5,
        ),
      )
    }
    CBoNa => {
      match extended_need(data, offset, 4) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      Ok((BitStringCommand(extended_read_u32(data, offset)), 4))
    }
    CIcNa => {
      match extended_need(data, offset, 1) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      Ok((InterrogationCommand(data[offset].to_int()), 1))
    }
    CCiNa => {
      match extended_need(data, offset, 1) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      Ok((CounterInterrogationCommand(data[offset].to_int()), 1))
    }
    CRdNa => Ok((ReadCommand, 0))
    CCsNa => {
      match extended_need(data, offset, 7) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      match Cp56Time::from_bytes(data, offset~) {
        Ok(value) => Ok((ClockSyncCommand(value), 7))
        Err(message) => Err(extended_error(InvalidQualifier, message, offset))
      }
    }
    CTsNa => {
      match extended_need(data, offset, 2) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      Ok((TestCommand(extended_read_u16(data, offset)), 2))
    }
    CRpNa => {
      match extended_need(data, offset, 1) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      Ok((ResetCommand(data[offset].to_int()), 1))
    }
    MEiNa => {
      match extended_need(data, offset, 1) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      Ok((EndOfInitialization(data[offset].to_int()), 1))
    }
    _ =>
      Err(
        extended_error(
          UnsupportedFeature,
          "application type is not implemented by the object decoder",
          offset,
        ),
      )
  }
}

///|
/// Decode a complete address-qualified ASDU.
pub fn decode_extended_asdu(data : Bytes) -> Result[AsduEnvelope, Diagnostic] {
  if data.length() < 6 {
    return Err(
      extended_error(MalformedFrame, "ASDU header is shorter than six bytes", 0),
    )
  }
  let type_id = application_type(data[0].to_int())
  let raw_count = data[1].to_int()
  let count = raw_count & 0x7f
  if count == 0 {
    return Err(
      extended_error(InvalidQualifier, "VSQ object count must not be zero", 1),
    )
  }
  let sequence = (raw_count & 0x80) != 0
  match
    CauseOfTransmission::from_number(
      data[2].to_int() & 0x3f,
      positive=(data[2].to_int() & 0x40) == 0,
      test_flag=(data[2].to_int() & 0x80) != 0,
      originator=data[3].to_int(),
    ) {
    Err(message) => Err(extended_error(InvalidQualifier, message, 2))
    Ok(cause) =>
      match CommonAddress::new(extended_read_u16(data, 4)) {
        Err(message) => Err(extended_error(InvalidAddress, message, 4))
        Ok(common_address) => {
          let tag_kind = time_tag_kind_for_type(type_id)
          let mut offset = 6
          let objects : Array[ApplicationObject] = []
          let mut previous_address = InformationAddress::new(0).unwrap()
          for index in 0..<count {
            let address = if sequence && index > 0 {
              match InformationAddress::new(previous_address.number() + 1) {
                Ok(value) => value
                Err(message) =>
                  return Err(extended_error(InvalidAddress, message, offset))
              }
            } else {
              match extended_read_address(data, offset) {
                Err(error) => return Err(error)
                Ok(value) => {
                  offset += 3
                  value
                }
              }
            }
            match extended_read_value(type_id, data, offset) {
              Err(error) => return Err(error)
              Ok((value, consumed)) => {
                offset += consumed
                let time_tag = if tag_kind is NoTimeTag {
                  None
                } else {
                  match decode_time_tag(tag_kind, data, offset~) {
                    Err(message) =>
                      return Err(
                        extended_error(InvalidQualifier, message, offset),
                      )
                    Ok(tag) => {
                      offset += tag.width()
                      Some(tag)
                    }
                  }
                }
                match make_application_object(address, value, time_tag) {
                  Err(message) =>
                    return Err(extended_error(InvalidType, message, offset))
                  Ok(object) => objects.push(object)
                }
                previous_address = address
              }
            }
          }
          if offset != data.length() {
            Err(
              extended_error(
                MalformedFrame,
                "ASDU contains trailing bytes",
                offset,
              ),
            )
          } else {
            match
              AsduEnvelope::new(
                type_id, sequence, cause, common_address, objects,
              ) {
              Ok(envelope) => Ok(envelope)
              Err(diagnostic) => Err(diagnostic)
            }
          }
        }
      }
  }
}

///|
/// Build an ASDU containing one object.
pub fn single_object_asdu(
  object : ApplicationObject,
  cause : CauseOfTransmission,
  common_address : CommonAddress,
) -> Result[AsduEnvelope, Diagnostic] {
  AsduEnvelope::new(object.type_id(), false, cause, common_address, [object])
}

///|
pub fn extended_asdu_examples() -> Array[AsduEnvelope] {
  let address = InformationAddress::new(1).unwrap()
  let common_address = CommonAddress::new(1).unwrap()
  let cause = CauseOfTransmission::new(Spontaneous).unwrap()
  match single_point_object(address, true) {
    Ok(object) => [single_object_asdu(object, cause, common_address).unwrap()]
    Err(_) => []
  }
}
