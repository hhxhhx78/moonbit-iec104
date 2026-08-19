///|
/// Convert a hexadecimal nibble to a display character.
pub fn hex_digit(value : Int) -> Char {
  let normalized = value & 0xf
  if normalized < 10 {
    ('0'.to_int() + normalized).to_char().unwrap()
  } else {
    ('a'.to_int() + normalized - 10).to_char().unwrap()
  }
}

///|
pub fn hex_encode(data : Bytes) -> String {
  let out = StringBuilder()
  for byte in data {
    out.write_char(hex_digit(byte.to_int() >> 4))
    out.write_char(hex_digit(byte.to_int()))
  }
  out.to_string()
}

///|
pub fn hex_value(value : Char) -> Int? {
  match value {
    '0'..='9' => Some(value.to_int() - '0'.to_int())
    'a'..='f' => Some(value.to_int() - 'a'.to_int() + 10)
    'A'..='F' => Some(value.to_int() - 'A'.to_int() + 10)
    _ => None
  }
}

///|
pub fn hex_decode(text : String) -> Result[Bytes, String] {
  let chars : Array[Char] = []
  for char in text {
    chars.push(char)
  }
  if chars.length() % 2 != 0 {
    Err("hexadecimal input must contain an even number of digits")
  } else {
    let out : Array[Byte] = []
    for index in 0..<(chars.length() / 2) {
      match (hex_value(chars[index * 2]), hex_value(chars[index * 2 + 1])) {
        (Some(high), Some(low)) => out.push(((high << 4) | low).to_byte())
        (_, _) => return Err("hexadecimal input contains an invalid digit")
      }
    }
    Ok(Bytes::from_array(out))
  }
}

///|
pub fn bytes_equal_left(a : Bytes, b : Bytes) -> Bool {
  if a.length() != b.length() {
    false
  } else {
    let mut equal = true
    for index in 0..<a.length() {
      if a[index] != b[index] {
        equal = false
      }
    }
    equal
  }
}

///|
pub fn xor_checksum(data : Bytes) -> Byte {
  let mut checksum : Int = 0
  for byte in data {
    checksum = checksum ^ byte.to_int()
  }
  checksum.to_byte()
}

///|
pub fn append_u24(out : Array[Byte], value : Int) -> Result[Unit, String] {
  if value < 0 || value > 0xffffff {
    Err("24-bit value is outside the protocol range")
  } else {
    out.push((value & 0xff).to_byte())
    out.push(((value >> 8) & 0xff).to_byte())
    out.push(((value >> 16) & 0xff).to_byte())
    Ok(())
  }
}

///|
pub fn read_u24(data : Bytes, offset : Int) -> Result[Int, String] {
  if offset < 0 || data.length() < offset + 3 {
    Err("24-bit value is truncated")
  } else {
    Ok(
      data[offset].to_int() |
      (data[offset + 1].to_int() << 8) |
      (data[offset + 2].to_int() << 16),
    )
  }
}

///|
/// A bounds-checked cursor for binary protocol decoders.
pub struct ByteCursor {
  data : Bytes
  mut offset : Int
} derive(Debug)

///|
pub fn ByteCursor::new(data : Bytes) -> ByteCursor {
  { data, offset: 0 }
}

///|
pub fn ByteCursor::offset(self : ByteCursor) -> Int {
  self.offset
}

///|
pub fn ByteCursor::remaining(self : ByteCursor) -> Int {
  self.data.length() - self.offset
}

///|
pub fn ByteCursor::done(self : ByteCursor) -> Bool {
  self.offset == self.data.length()
}

///|
pub fn ByteCursor::read_byte(self : ByteCursor) -> Result[Byte, Diagnostic] {
  if self.offset >= self.data.length() {
    Err(
      Diagnostic::new(
        MalformedFrame,
        "cursor reached the end of input",
        offset=self.offset,
      ),
    )
  } else {
    let value = self.data[self.offset]
    self.offset += 1
    Ok(value)
  }
}

///|
pub fn ByteCursor::read_u16(self : ByteCursor) -> Result[Int, Diagnostic] {
  if self.remaining() < 2 {
    Err(
      Diagnostic::new(
        MalformedFrame,
        "cursor cannot read a 16-bit value",
        offset=self.offset,
      ),
    )
  } else {
    let value = self.data[self.offset].to_int() |
      (self.data[self.offset + 1].to_int() << 8)
    self.offset += 2
    Ok(value)
  }
}

///|
pub fn ByteCursor::read_u24(self : ByteCursor) -> Result[Int, Diagnostic] {
  if self.remaining() < 3 {
    Err(
      Diagnostic::new(
        MalformedFrame,
        "cursor cannot read a 24-bit value",
        offset=self.offset,
      ),
    )
  } else {
    let value = self.data[self.offset].to_int() |
      (self.data[self.offset + 1].to_int() << 8) |
      (self.data[self.offset + 2].to_int() << 16)
    self.offset += 3
    Ok(value)
  }
}

///|
pub fn ByteCursor::read_u32(self : ByteCursor) -> Result[UInt, Diagnostic] {
  if self.remaining() < 4 {
    Err(
      Diagnostic::new(
        MalformedFrame,
        "cursor cannot read a 32-bit value",
        offset=self.offset,
      ),
    )
  } else {
    let value = self.data[self.offset].to_int().reinterpret_as_uint() |
      (self.data[self.offset + 1].to_int().reinterpret_as_uint() << 8) |
      (self.data[self.offset + 2].to_int().reinterpret_as_uint() << 16) |
      (self.data[self.offset + 3].to_int().reinterpret_as_uint() << 24)
    self.offset += 4
    Ok(value)
  }
}

///|
pub fn ByteCursor::read_bytes(
  self : ByteCursor,
  length : Int,
) -> Result[Bytes, Diagnostic] {
  if length < 0 || self.remaining() < length {
    Err(
      Diagnostic::new(
        MalformedFrame,
        "cursor cannot read the requested byte span",
        offset=self.offset,
      ),
    )
  } else {
    let value = self.data[self.offset:self.offset + length].to_owned()
    self.offset += length
    Ok(value)
  }
}

///|
pub fn ByteCursor::skip(
  self : ByteCursor,
  length : Int,
) -> Result[Unit, Diagnostic] {
  if length < 0 || self.remaining() < length {
    Err(
      Diagnostic::new(
        MalformedFrame,
        "cursor cannot skip the requested span",
        offset=self.offset,
      ),
    )
  } else {
    self.offset += length
    Ok(())
  }
}

///|
pub fn ByteCursor::seek(
  self : ByteCursor,
  offset : Int,
) -> Result[Unit, Diagnostic] {
  if offset < 0 || offset > self.data.length() {
    Err(
      Diagnostic::new(MalformedFrame, "cursor seek is outside input", offset~),
    )
  } else {
    self.offset = offset
    Ok(())
  }
}

///|
/// A small writer used by application-specific extensions.
pub struct ByteWriter {
  bytes : Array[Byte]
} derive(Debug)

///|
pub fn ByteWriter::new() -> ByteWriter {
  { bytes: [] }
}

///|
pub fn ByteWriter::len(self : ByteWriter) -> Int {
  self.bytes.length()
}

///|
pub fn ByteWriter::push(self : ByteWriter, value : Byte) -> Unit {
  self.bytes.push(value)
}

///|
pub fn ByteWriter::push_u16(
  self : ByteWriter,
  value : Int,
) -> Result[Unit, String] {
  if value < 0 || value > 65535 {
    Err("writer 16-bit value is outside range")
  } else {
    self.bytes.push((value & 0xff).to_byte())
    self.bytes.push(((value >> 8) & 0xff).to_byte())
    Ok(())
  }
}

///|
pub fn ByteWriter::push_u24(
  self : ByteWriter,
  value : Int,
) -> Result[Unit, String] {
  append_u24(self.bytes, value)
}

///|
pub fn ByteWriter::push_u32(self : ByteWriter, value : UInt) -> Unit {
  self.bytes.push((value & 0xffU).to_byte())
  self.bytes.push(((value >> 8) & 0xffU).to_byte())
  self.bytes.push(((value >> 16) & 0xffU).to_byte())
  self.bytes.push(((value >> 24) & 0xffU).to_byte())
}

///|
pub fn ByteWriter::push_bytes(self : ByteWriter, value : Bytes) -> Unit {
  for byte in value {
    self.bytes.push(byte)
  }
}

///|
pub fn ByteWriter::to_bytes(self : ByteWriter) -> Bytes {
  Bytes::from_array(self.bytes)
}

///|
/// Split a byte stream into complete APDUs and retain incomplete tails.
pub fn split_apdus(data : Bytes) -> Result[(Array[Frame], Bytes), Diagnostic] {
  let frames : Array[Frame] = []
  let mut offset = 0
  while offset < data.length() {
    match parse_apdu_prefix(data[offset:].to_owned()) {
      Complete(frame, consumed) => {
        frames.push(frame)
        offset += consumed
      }
      NeedMore(_) => return Ok((frames, data[offset:].to_owned()))
      Invalid(error) => return Err(error)
    }
  }
  Ok((frames, b""))
}

///|
pub fn pad_bytes(
  data : Bytes,
  length : Int,
  fill : Byte,
) -> Result[Bytes, String] {
  if length < data.length() {
    Err("padding length is shorter than input")
  } else {
    let out = data.to_array()
    while out.length() < length {
      out.push(fill)
    }
    Ok(Bytes::from_array(out))
  }
}

///|
pub fn trim_trailing_bytes(data : Bytes, value : Byte) -> Bytes {
  let mut end = data.length()
  while end > 0 && data[end - 1] == value {
    end -= 1
  }
  data[:end].to_owned()
}

///|
pub fn bit_is_set(value : Int, bit : Int) -> Bool {
  bit >= 0 && bit < 31 && (value & (1 << bit)) != 0
}

///|
pub fn set_bit(value : Int, bit : Int, enabled : Bool) -> Int {
  if bit < 0 || bit >= 31 {
    value
  } else if enabled {
    value | (1 << bit)
  } else {
    value & (0x7fffffff ^ (1 << bit))
  }
}

///|
pub fn mask_bits(value : Int, mask : Int) -> Int {
  value & mask
}

///|
pub fn wire_tool_examples() -> Array[Bytes] {
  [
    hex_decode("680401000000").unwrap(),
    trim_trailing_bytes(b"abc\x00\x00", b'\x00'),
  ]
}
