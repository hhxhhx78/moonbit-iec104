///|
/// The three-byte information object address used by IEC 104.
pub struct InformationAddress {
  value : Int
} derive(Eq, Debug)

///|
/// Create an information object address in the inclusive 0..0xffffff range.
pub fn InformationAddress::new(
  value : Int,
) -> Result[InformationAddress, String] {
  if value < 0 || value > 0xffffff {
    Err("information object address must fit 24 bits")
  } else {
    Ok({ value, })
  }
}

///|
/// Construct an information object address from its three octets.
pub fn InformationAddress::from_octets(
  low : Int,
  middle : Int,
  high : Int,
) -> Result[InformationAddress, String] {
  if low < 0 ||
    low > 255 ||
    middle < 0 ||
    middle > 255 ||
    high < 0 ||
    high > 255 {
    Err("information object address octets must fit one byte")
  } else {
    Ok({ value: low | (middle << 8) | (high << 16) })
  }
}

///|
/// Return the numeric address.
pub fn InformationAddress::number(self : InformationAddress) -> Int {
  self.value
}

///|
/// Return the least significant address octet.
pub fn InformationAddress::low(self : InformationAddress) -> Int {
  self.value & 0xff
}

///|
/// Return the middle address octet.
pub fn InformationAddress::middle(self : InformationAddress) -> Int {
  (self.value >> 8) & 0xff
}

///|
/// Return the most significant address octet.
pub fn InformationAddress::high(self : InformationAddress) -> Int {
  (self.value >> 16) & 0xff
}

///|
/// Return whether the address is the protocol's broadcast address.
pub fn InformationAddress::is_broadcast(self : InformationAddress) -> Bool {
  self.value == 0xffffff
}

///|
/// Common address of ASDU values. Zero is reserved for an unassigned station.
pub struct CommonAddress {
  value : Int
} derive(Eq, Debug)

///|
/// Create a two-byte common address.
pub fn CommonAddress::new(value : Int) -> Result[CommonAddress, String] {
  if value < 0 || value > 0xffff {
    Err("common address must fit 16 bits")
  } else {
    Ok({ value, })
  }
}

///|
/// Return the numeric common address.
pub fn CommonAddress::number(self : CommonAddress) -> Int {
  self.value
}

///|
/// Return whether this common address is the global station address.
pub fn CommonAddress::is_global(self : CommonAddress) -> Bool {
  self.value == 0xffff
}

///|
/// Cause of transmission category. The numeric value is kept separate from
/// the qualifier so applications can preserve vendor extensions.
pub enum CauseCategory {
  Periodic
  Background
  Spontaneous
  Initialised
  Request
  Activation
  ActivationConfirmation
  ActivationTermination
  ReturnInformationRemote
  ReturnInformationLocal
  UnknownCause
} derive(Eq, Debug)

///|
/// Return the standard six-bit cause value.
pub fn CauseCategory::number(self : CauseCategory) -> Int {
  match self {
    Periodic => 1
    Background => 2
    Spontaneous => 3
    Initialised => 4
    Request => 5
    Activation => 6
    ActivationConfirmation => 7
    ActivationTermination => 10
    ReturnInformationRemote => 11
    ReturnInformationLocal => 12
    UnknownCause => 0
  }
}

///|
/// Decode a standard cause category without rejecting extension values.
pub fn cause_category(value : Int) -> CauseCategory {
  match value {
    1 => Periodic
    2 => Background
    3 => Spontaneous
    4 => Initialised
    5 => Request
    6 => Activation
    7 => ActivationConfirmation
    10 => ActivationTermination
    11 => ReturnInformationRemote
    12 => ReturnInformationLocal
    _ => UnknownCause
  }
}

///|
/// Full cause of transmission, including the originator and qualifier bits.
pub struct CauseOfTransmission {
  category : CauseCategory
  number : Int
  positive : Bool
  test_flag : Bool
  originator : Int
  qualifier : Int
} derive(Eq, Debug)

///|
/// Construct a validated cause of transmission.
pub fn CauseOfTransmission::new(
  category : CauseCategory,
  positive? : Bool = true,
  test_flag? : Bool = false,
  originator? : Int = 0,
  qualifier? : Int = 0,
) -> Result[CauseOfTransmission, String] {
  if originator < 0 || originator > 255 {
    Err("originator address must fit 8 bits")
  } else if qualifier < 0 || qualifier > 0x3f {
    Err("cause qualifier must fit 6 bits")
  } else {
    Ok({
      category,
      number: category.number(),
      positive,
      test_flag,
      originator,
      qualifier,
    })
  }
}

///|
/// Construct a cause from a raw standard number while preserving extension data.
pub fn CauseOfTransmission::from_number(
  number : Int,
  positive? : Bool = true,
  test_flag? : Bool = false,
  originator? : Int = 0,
  qualifier? : Int = 0,
) -> Result[CauseOfTransmission, String] {
  match
    CauseOfTransmission::new(
      cause_category(number),
      positive~,
      test_flag~,
      originator~,
      qualifier~,
    ) {
    Ok(value) =>
      Ok({
        category: value.category,
        number,
        positive: value.positive,
        test_flag: value.test_flag,
        originator: value.originator,
        qualifier: value.qualifier,
      })
    Err(error) => Err(error)
  }
}

///|
/// Return the raw cause number.
pub fn CauseOfTransmission::raw(self : CauseOfTransmission) -> Int {
  self.number
}

///|
/// Return the four low flag bits in the IEC COT representation.
pub fn CauseOfTransmission::flags(self : CauseOfTransmission) -> Int {
  (if self.positive { 0 } else { 0x40 }) |
  (if self.test_flag { 0x80 } else { 0 }) |
  (self.number & 0x3f)
}

///|
/// Return the qualifier value.
pub fn CauseOfTransmission::qualifier(self : CauseOfTransmission) -> Int {
  self.qualifier
}

///|
/// Return the originator address.
pub fn CauseOfTransmission::originator(self : CauseOfTransmission) -> Int {
  self.originator
}

///|
/// Standard IEC 104 application type identifiers.
pub enum ApplicationType {
  MSpNa
  MSpTa
  MDpNa
  MDpTa
  MStNa
  MStTa
  MBoNa
  MBoTa
  MMeNa
  MMeTa
  MMeNb
  MMeTb
  MMeNc
  MMeTc
  MItNa
  MItTa
  MEpTa
  MEpTb
  MEpTc
  MPsNa
  MMeNd
  MSpTb
  MDpTb
  MStTb
  MBoTb
  MMeTd
  MMeTe
  MMeTf
  MItTb
  MEpTd
  MEpTe
  MEpTf
  MEiNa
  CScNa
  CDcNa
  CRcNa
  CSeNa
  CSeNb
  CSeNc
  CBoNa
  CIcNa
  CCiNa
  CRdNa
  CCsNa
  CTsNa
  CRpNa
  UnknownType(Int)
} derive(Eq, Debug)

///|
/// Return an IEC 104 type identifier number.
pub fn ApplicationType::number(self : ApplicationType) -> Int {
  match self {
    MSpNa => 1
    MSpTa => 2
    MDpNa => 3
    MDpTa => 4
    MStNa => 5
    MStTa => 6
    MBoNa => 7
    MBoTa => 8
    MMeNa => 9
    MMeTa => 10
    MMeNb => 11
    MMeTb => 12
    MMeNc => 13
    MMeTc => 14
    MItNa => 15
    MItTa => 16
    MEpTa => 17
    MEpTb => 18
    MEpTc => 19
    MPsNa => 20
    MMeNd => 21
    MSpTb => 30
    MDpTb => 31
    MStTb => 32
    MBoTb => 33
    MMeTd => 34
    MMeTe => 35
    MMeTf => 36
    MItTb => 37
    MEpTd => 38
    MEpTe => 39
    MEpTf => 40
    MEiNa => 70
    CScNa => 45
    CDcNa => 46
    CRcNa => 47
    CSeNa => 48
    CSeNb => 49
    CSeNc => 50
    CBoNa => 51
    CIcNa => 100
    CCiNa => 101
    CRdNa => 102
    CCsNa => 103
    CTsNa => 104
    CRpNa => 105
    UnknownType(value) => value
  }
}

///|
/// Decode all currently assigned standard IEC 104 type identifiers.
pub fn application_type(value : Int) -> ApplicationType {
  match value {
    1 => MSpNa
    2 => MSpTa
    3 => MDpNa
    4 => MDpTa
    5 => MStNa
    6 => MStTa
    7 => MBoNa
    8 => MBoTa
    9 => MMeNa
    10 => MMeTa
    11 => MMeNb
    12 => MMeTb
    13 => MMeNc
    14 => MMeTc
    15 => MItNa
    16 => MItTa
    17 => MEpTa
    18 => MEpTb
    19 => MEpTc
    20 => MPsNa
    21 => MMeNd
    30 => MSpTb
    31 => MDpTb
    32 => MStTb
    33 => MBoTb
    34 => MMeTd
    35 => MMeTe
    36 => MMeTf
    37 => MItTb
    38 => MEpTd
    39 => MEpTe
    40 => MEpTf
    45 => CScNa
    46 => CDcNa
    47 => CRcNa
    48 => CSeNa
    49 => CSeNb
    50 => CSeNc
    51 => CBoNa
    70 => MEiNa
    100 => CIcNa
    101 => CCiNa
    102 => CRdNa
    103 => CCsNa
    104 => CTsNa
    105 => CRpNa
    _ => UnknownType(value)
  }
}

///|
/// Whether an application type belongs to monitor direction data.
pub fn ApplicationType::is_monitoring(self : ApplicationType) -> Bool {
  self.number() < 45 || self is MEiNa
}

///|
/// Whether an application type belongs to control direction data.
pub fn ApplicationType::is_control(self : ApplicationType) -> Bool {
  (self.number() >= 45 && self.number() < 70) || self.number() >= 100
}

///|
/// Whether a type carries a CP24 or CP56 time tag.
pub fn ApplicationType::has_time_tag(self : ApplicationType) -> Bool {
  match self {
    MSpTa
    | MDpTa
    | MStTa
    | MBoTa
    | MMeTa
    | MMeTb
    | MMeTc
    | MItTa
    | MSpTb
    | MDpTb
    | MStTb
    | MBoTb
    | MMeTd
    | MMeTe
    | MMeTf
    | MItTb
    | MEpTa
    | MEpTb
    | MEpTc
    | MEpTe
    | MEpTf => true
    _ => false
  }
}

///|
/// Preferred information-object payload width, excluding IOA and time tag.
pub fn ApplicationType::value_width(self : ApplicationType) -> Int? {
  match self {
    MSpNa | MSpTa | MSpTb => Some(1)
    MDpNa | MDpTa | MDpTb => Some(1)
    MStNa | MStTa | MStTb => Some(2)
    MBoNa | MBoTa | MBoTb => Some(5)
    MMeNa | MMeTa | MMeNb | MMeTb | MMeNd | MMeTd | MMeTe => Some(3)
    MMeNc | MMeTc | MMeTf => Some(5)
    MItNa | MItTa | MItTb => Some(5)
    _ => None
  }
}

///|
/// IEC 104 link-layer timing and window parameters.
pub struct ConnectionParameters {
  k : Int
  w : Int
  t0_seconds : Int
  t1_seconds : Int
  t2_seconds : Int
  t3_seconds : Int
} derive(Eq, Debug)

///|
/// Default parameters from the commonly deployed IEC 104 profile.
pub fn ConnectionParameters::default() -> ConnectionParameters {
  {
    k: 12,
    w: 8,
    t0_seconds: 30,
    t1_seconds: 15,
    t2_seconds: 10,
    t3_seconds: 20,
  }
}

///|
/// Validate and construct link-layer parameters.
pub fn ConnectionParameters::new(
  k : Int,
  w : Int,
  t0_seconds : Int,
  t1_seconds : Int,
  t2_seconds : Int,
  t3_seconds : Int,
) -> Result[ConnectionParameters, String] {
  if k < 1 || k > 32767 {
    Err("k must be between 1 and 32767")
  } else if w < 1 || w > 32767 || w > k {
    Err("w must be between 1 and k")
  } else if t0_seconds < 1 || t1_seconds < 1 || t2_seconds < 1 || t3_seconds < 1 {
    Err("IEC timers must be positive")
  } else if t2_seconds > t1_seconds || t1_seconds > t0_seconds {
    Err("IEC timer ordering requires t2 <= t1 <= t0")
  } else {
    Ok({ k, w, t0_seconds, t1_seconds, t2_seconds, t3_seconds })
  }
}

///|
pub fn ConnectionParameters::k(self : ConnectionParameters) -> Int {
  self.k
}

///|
pub fn ConnectionParameters::w(self : ConnectionParameters) -> Int {
  self.w
}

///|
pub fn ConnectionParameters::t0(self : ConnectionParameters) -> Int {
  self.t0_seconds
}

///|
pub fn ConnectionParameters::t1(self : ConnectionParameters) -> Int {
  self.t1_seconds
}

///|
pub fn ConnectionParameters::t2(self : ConnectionParameters) -> Int {
  self.t2_seconds
}

///|
pub fn ConnectionParameters::t3(self : ConnectionParameters) -> Int {
  self.t3_seconds
}

///|
/// A stable classification for protocol diagnostics.
pub enum DiagnosticKind {
  MalformedFrame
  InvalidSequence
  InvalidAddress
  InvalidType
  InvalidQualifier
  UnsupportedFeature
  WindowExhausted
  TimerExpired
  StateViolation
  TransportFailure
} derive(Eq, Debug)

///|
/// Structured diagnostic returned by validation and service layers.
pub struct Diagnostic {
  kind : DiagnosticKind
  message : String
  offset : Int?
} derive(Eq, Debug)

///|
pub fn Diagnostic::new(
  kind : DiagnosticKind,
  message : String,
  offset? : Int,
) -> Diagnostic {
  { kind, message, offset }
}

///|
pub fn Diagnostic::kind(self : Diagnostic) -> DiagnosticKind {
  self.kind
}

///|
pub fn Diagnostic::message(self : Diagnostic) -> String {
  self.message
}

///|
pub fn Diagnostic::offset(self : Diagnostic) -> Int? {
  self.offset
}

///|
/// Produce a compact human-readable diagnostic line for CLI and logs.
pub fn Diagnostic::to_line(self : Diagnostic) -> String {
  match self.offset {
    Some(offset) => "\{self.message} at byte \{offset}"
    None => self.message
  }
}

///|
/// Keep all diagnostic categories available to host-side telemetry adapters.
pub fn diagnostic_kind_examples() -> Array[DiagnosticKind] {
  [
    MalformedFrame,
    InvalidSequence,
    InvalidAddress,
    InvalidType,
    InvalidQualifier,
    UnsupportedFeature,
    WindowExhausted,
    TimerExpired,
    StateViolation,
    TransportFailure,
  ]
}
