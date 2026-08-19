///|
/// Stable accessors for frame values used by host integrations.
pub fn Frame::kind(self : Frame) -> FrameKind {
  self.kind
}

///|
pub fn Frame::send_sequence(self : Frame) -> Int {
  self.send_sequence
}

///|
pub fn Frame::receive_sequence(self : Frame) -> Int {
  self.receive_sequence
}

///|
pub fn Frame::control(self : Frame) -> UInt16 {
  self.control
}

///|
pub fn Frame::payload(self : Frame) -> Bytes {
  self.payload
}

///|
pub fn Frame::is_information(self : Frame) -> Bool {
  self.kind == Information
}

///|
pub fn Frame::is_supervisory(self : Frame) -> Bool {
  self.kind == Supervisory
}

///|
pub fn Frame::is_unnumbered(self : Frame) -> Bool {
  self.kind == Unnumbered
}

///|
pub fn TypeId::is_known(self : TypeId) -> Bool {
  match self {
    Unknown(_) => false
    _ => true
  }
}

///|
pub fn TypeId::name(self : TypeId) -> String {
  match self {
    SinglePoint => "M_SP_NA_1"
    DoublePoint => "M_DP_NA_1"
    NormalizedValue => "M_ME_NA_1"
    ShortFloat => "M_ME_NC_1"
    BitString32 => "M_BO_NA_1"
    Unknown(_) => "UNKNOWN"
  }
}

///|
pub fn AsduHeader::count(self : AsduHeader) -> Int {
  self.variable_count
}

///|
pub fn AsduHeader::type_id(self : AsduHeader) -> TypeId {
  self.type_id
}

///|
pub fn AsduHeader::cause(self : AsduHeader) -> Int {
  self.cause
}

///|
pub fn AsduHeader::common_address(self : AsduHeader) -> Int {
  self.common_address
}

///|
pub fn AsduHeader::is_sequence(self : AsduHeader) -> Bool {
  self.sequence
}

///|
pub fn Cause::is_activation(self : Cause) -> Bool {
  self == Activation
}

///|
pub fn Cause::is_termination(self : Cause) -> Bool {
  self == ActivationTermination
}

///|
pub fn Cause::is_spontaneous(self : Cause) -> Bool {
  self == Spontaneous
}

///|
pub fn LinkState::is_connected(self : LinkState) -> Bool {
  self == Started || self == TestPending
}

///|
pub fn LinkState::is_terminal(self : LinkState) -> Bool {
  self == Disconnected || self == Stopped
}

///|
pub fn type_id_examples() -> Array[TypeId] {
  [
    SinglePoint,
    DoublePoint,
    NormalizedValue,
    ShortFloat,
    BitString32,
    Unknown(255),
  ]
}
