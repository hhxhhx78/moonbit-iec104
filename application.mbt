///|
/// Standard causes of transmission used by IEC 104 application services.
pub enum Cause {
  Periodic
  Background
  Spontaneous
  Initialised
  Request
  Activation
  ActivationConfirmation
  ActivationTermination
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn Cause::number(self : Cause) -> Int {
  match self {
    Periodic => 1
    Background => 2
    Spontaneous => 3
    Initialised => 4
    Request => 5
    Activation => 6
    ActivationConfirmation => 7
    ActivationTermination => 10
    Unknown(value) => value
  }
}

///|
pub fn cause(value : Int) -> Cause {
  match value {
    1 => Periodic
    2 => Background
    3 => Spontaneous
    4 => Initialised
    5 => Request
    6 => Activation
    7 => ActivationConfirmation
    10 => ActivationTermination
    value => Unknown(value)
  }
}

///|
/// A total interrogation request, suitable for a master command queue.
pub struct InterrogationRequest {
  common_address : Int
  qualifier : Int
} derive(Eq, Debug)

///|
pub fn InterrogationRequest::new(
  common_address : Int,
  qualifier? : Int = 20,
) -> InterrogationRequest {
  { common_address, qualifier }
}

///|
/// Phases emitted by an interrogation transaction.
pub enum InterrogationPhase {
  Idle
  Activated
  Sending
  Terminated
} derive(Eq, Debug)

///|
/// Small deterministic transaction tracker; data transport remains caller-owned.
pub struct Interrogation {
  request : InterrogationRequest
  mut phase : InterrogationPhase
  mut objects_sent : Int
}

///|
pub fn Interrogation::new(request : InterrogationRequest) -> Interrogation {
  { request, phase: Idle, objects_sent: 0 }
}

///|
pub fn Interrogation::activate(self : Interrogation) -> Int {
  self.phase = Activated
  Cause::Activation.number()
}

///|
pub fn Interrogation::record(
  self : Interrogation,
  count : Int,
) -> Result[Unit, String] {
  if self.phase != Activated && self.phase != Sending {
    return Err("interrogation is not active")
  }
  self.phase = Sending
  self.objects_sent += if count < 0 { 0 } else { count }
  Ok(())
}

///|
pub fn Interrogation::finish(self : Interrogation) -> Int {
  self.phase = Terminated
  Cause::ActivationTermination.number()
}

///|
/// An immutable snapshot of values that can be used to build a response ASDU.
pub struct PointSnapshot {
  ioa : Int
  value : InformationObject
}

///|
pub fn Outstation::snapshot_single(self : Outstation) -> Array[PointSnapshot] {
  let result : Array[PointSnapshot] = []
  for ioa, value in self.single_points {
    result.push({ ioa, value: Single(value, 0) })
  }
  result
}

///|
pub fn Outstation::snapshot_normalized(
  self : Outstation,
) -> Array[PointSnapshot] {
  let result : Array[PointSnapshot] = []
  for ioa, value in self.normalized_values {
    result.push({ ioa, value: Normalized(value, 0) })
  }
  result
}
