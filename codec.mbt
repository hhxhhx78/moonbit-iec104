///|
/// Internal byte helpers for little-endian IEC 104 fields.
fn low_byte(value : Int) -> Byte {
  (value % 256).to_byte()
}

///|
fn high_byte(value : Int) -> Byte {
  (value / 256 % 256).to_byte()
}

///|
fn read_u16(bytes : Bytes, offset : Int) -> Int {
  bytes[offset].to_int() + bytes[offset + 1].to_int() * 256
}

///|
fn read_u32(bytes : Bytes, offset : Int) -> UInt {
  bytes[offset].to_int().reinterpret_as_uint() |
  (bytes[offset + 1].to_int().reinterpret_as_uint() << 8) |
  (bytes[offset + 2].to_int().reinterpret_as_uint() << 16) |
  (bytes[offset + 3].to_int().reinterpret_as_uint() << 24)
}

///|
fn append_u16(out : Array[Byte], value : Int) -> Unit {
  out.push(low_byte(value))
  out.push(high_byte(value))
}

///|
fn append_u32(out : Array[Byte], value : UInt) -> Unit {
  out.push((value & 0xffU).to_byte())
  out.push(((value >> 8) & 0xffU).to_byte())
  out.push(((value >> 16) & 0xffU).to_byte())
  out.push(((value >> 24) & 0xffU).to_byte())
}

///|
/// Encode one APCI frame, including the 0x68 start byte and length byte.
pub fn encode_frame(frame : Frame) -> Bytes {
  let control : UInt = match frame.kind {
    Information =>
      (frame.send_sequence.reinterpret_as_uint() << 1) |
      (frame.receive_sequence.reinterpret_as_uint() << 17)
    Supervisory => 1U | (frame.receive_sequence.reinterpret_as_uint() << 17)
    Unnumbered => frame.control.to_uint()
  }
  let payload = frame.payload.to_array()
  let out : Array[Byte] = [b'\x68', (4 + payload.length()).to_byte()]
  append_u32(out, control)
  for byte in payload {
    out.push(byte)
  }
  Bytes::from_array(out)
}

///|
/// Decode one complete APDU. Extra bytes after the declared APDU are rejected.
pub fn decode_frame(data : Bytes) -> Result[Frame, String] {
  if data.length() < 6 {
    return Err("APDU is shorter than six bytes")
  }
  if data[0] != b'\x68' {
    return Err("invalid APDU start byte")
  }
  let length = data[1].to_int()
  if length < 4 || data.length() != length + 2 {
    return Err("APDU length mismatch")
  }
  let control = read_u32(data, 2)
  if (control & 1U) == 0U {
    Ok(
      information_frame(
        (control & 0xffffU).reinterpret_as_int() / 2,
        (control >> 16).reinterpret_as_int() / 2,
        data[6:].to_owned(),
      ),
    )
  } else if (control & 2U) == 0U {
    Ok(supervisory_frame((control >> 16).reinterpret_as_int() / 2))
  } else {
    Ok(unnumbered_frame(control.to_uint16()))
  }
}

///|
/// Encode an ASDU header followed by information objects.
pub fn encode_asdu(
  header : AsduHeader,
  objects : Array[InformationObject],
) -> Bytes {
  let sequence_flag = if header.sequence { 0x80 } else { 0 }
  let out : Array[Byte] = [
    header.type_id.number().to_byte(),
    (header.variable_count | sequence_flag).to_byte(),
  ]
  append_u16(out, header.cause)
  append_u16(out, header.common_address)
  for object in objects {
    match object {
      Single(status, quality) => {
        out.push(if status { 1 } else { 0 })
        out.push(low_byte(quality))
      }
      Double(status, quality) => {
        out.push(status.to_byte())
        out.push(low_byte(quality))
      }
      Normalized(value, quality) => {
        append_u16(out, value)
        out.push(low_byte(quality))
      }
      ShortFloat(value, quality) => {
        let bits = value.reinterpret_as_uint()
        append_u32(out, bits)
        out.push(low_byte(quality))
      }
      BitString(value, quality) => {
        append_u32(out, value)
        out.push(low_byte(quality))
      }
    }
  }
  Bytes::from_array(out)
}

///|
/// Decode an ASDU header and its information objects.
pub fn decode_asdu(
  data : Bytes,
) -> Result[(AsduHeader, Array[InformationObject]), String] {
  if data.length() < 6 {
    return Err("ASDU header is incomplete")
  }
  let raw_count = data[1].to_int()
  let header = {
    type_id: type_id(data[0].to_int()),
    variable_count: raw_count & 0x7f,
    sequence: (raw_count & 0x80) != 0,
    cause: read_u16(data, 2),
    common_address: read_u16(data, 4),
  }
  let width = match header.type_id {
    SinglePoint => 2
    DoublePoint => 2
    NormalizedValue => 3
    ShortFloat => 5
    BitString32 => 5
    Unknown(_) => return Err("unsupported information type")
  }
  if data.length() != 6 + width * header.variable_count {
    return Err("ASDU object length mismatch")
  }
  let objects : Array[InformationObject] = []
  let mut offset = 6
  for _ in 0..<header.variable_count {
    match header.type_id {
      SinglePoint => {
        objects.push(
          Single(data[offset].to_int() != 0, data[offset + 1].to_int()),
        )
        offset += 2
      }
      DoublePoint => {
        objects.push(Double(data[offset].to_int(), data[offset + 1].to_int()))
        offset += 2
      }
      NormalizedValue => {
        objects.push(
          Normalized(read_u16(data, offset), data[offset + 2].to_int()),
        )
        offset += 3
      }
      ShortFloat => {
        let raw = read_u32(data, offset)
        objects.push(
          ShortFloat(
            Float::reinterpret_from_uint(raw),
            data[offset + 4].to_int(),
          ),
        )
        offset += 5
      }
      BitString32 => {
        objects.push(
          BitString(read_u32(data, offset), data[offset + 4].to_int()),
        )
        offset += 5
      }
      Unknown(_) => return Err("unsupported information type")
    }
  }
  Ok((header, objects))
}
