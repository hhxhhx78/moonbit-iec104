///|
/// IEC 60870-5-104 frame kinds.
pub enum FrameKind {
  Information
  Supervisory
  Unnumbered
} derive(Eq, Debug)

///|
/// A decoded APCI frame. `payload` contains the ASDU for I frames.
pub struct Frame {
  kind : FrameKind
  send_sequence : Int
  receive_sequence : Int
  control : UInt16
  payload : Bytes
} derive(Eq, Debug)

///|
/// Create an I frame from a sequence pair and an ASDU payload.
pub fn information_frame(
  send_sequence : Int,
  receive_sequence : Int,
  payload : Bytes,
) -> Frame {
  { kind: Information, send_sequence, receive_sequence, control: 0, payload }
}

///|
/// Create an S frame acknowledging received I frames.
pub fn supervisory_frame(receive_sequence : Int) -> Frame {
  {
    kind: Supervisory,
    send_sequence: 0,
    receive_sequence,
    control: 1,
    payload: b"",
  }
}

///|
/// Create a U frame. The low six control bits are retained by the encoder.
pub fn unnumbered_frame(control : UInt16) -> Frame {
  {
    kind: Unnumbered,
    send_sequence: 0,
    receive_sequence: 0,
    control,
    payload: b"",
  }
}

///|
/// IEC 104 U-frame commands.
pub enum UCommand {
  StartDataTransfer
  StopDataTransfer
  TestFrame
  Unknown(UInt16)
} derive(Eq, Debug)

///|
pub fn UCommand::control(self : UCommand) -> UInt16 {
  match self {
    StartDataTransfer => 0x0007
    StopDataTransfer => 0x0013
    TestFrame => 0x0043
    Unknown(value) => value
  }
}

///|
pub fn u_command(control : UInt16) -> UCommand {
  match control {
    0x0007 => StartDataTransfer
    0x0013 => StopDataTransfer
    0x0043 => TestFrame
    value => Unknown(value)
  }
}

///|
/// Application type identifiers used by this library.
pub enum TypeId {
  SinglePoint
  DoublePoint
  NormalizedValue
  ShortFloat
  BitString32
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn TypeId::number(self : TypeId) -> Int {
  match self {
    SinglePoint => 1
    DoublePoint => 3
    NormalizedValue => 9
    ShortFloat => 13
    BitString32 => 7
    Unknown(n) => n
  }
}

///|
pub fn type_id(value : Int) -> TypeId {
  match value {
    1 => SinglePoint
    3 => DoublePoint
    7 => BitString32
    9 => NormalizedValue
    13 => ShortFloat
    value => Unknown(value)
  }
}

///|
/// Common information object address and cause of transmission.
pub struct AsduHeader {
  type_id : TypeId
  variable_count : Int
  sequence : Bool
  cause : Int
  common_address : Int
} derive(Eq, Debug)

///|
/// IEC information object values supported by the first stable API.
pub enum InformationObject {
  Single(Bool, Int)
  Double(Int, Int)
  Normalized(Int, Int)
  ShortFloat(Float, Int)
  BitString(UInt, Int)
} derive(Eq, Debug)
