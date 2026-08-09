///|
/// Build a single-point status ASDU.
pub fn single_point_asdu(
  cause : Int,
  common_address : Int,
  ioa : Int,
  status : Bool,
  quality : Int,
) -> Bytes {
  let header = {
    type_id: SinglePoint,
    variable_count: 1,
    sequence: false,
    cause,
    common_address,
  }
  let body = encode_asdu(header, [Single(status, quality)])
  let out = body.to_array()
  let address = ioa
  out.insert(6, high_byte(address))
  out.insert(6, low_byte(address))
  Bytes::from_array(out)
}

///|
/// Build a normalized telemetry value.
pub fn normalized_value_asdu(
  cause : Int,
  common_address : Int,
  value : Int,
  quality : Int,
) -> Bytes {
  encode_asdu(
    {
      type_id: NormalizedValue,
      variable_count: 1,
      sequence: false,
      cause,
      common_address,
    },
    [Normalized(value, quality)],
  )
}

///|
/// A compact in-memory outstation used in tests, demos and protocol simulations.
pub struct Outstation {
  common_address : Int
  single_points : Map[Int, Bool]
  normalized_values : Map[Int, Int]
}

///|
pub fn Outstation::new(common_address : Int) -> Outstation {
  { common_address, single_points: {}, normalized_values: {} }
}

///|
pub fn Outstation::set_single(
  self : Outstation,
  ioa : Int,
  value : Bool,
) -> Unit {
  self.single_points[ioa] = value
}

///|
pub fn Outstation::set_normalized(
  self : Outstation,
  ioa : Int,
  value : Int,
) -> Unit {
  self.normalized_values[ioa] = value
}

///|
pub fn Outstation::single(self : Outstation, ioa : Int) -> Bool? {
  self.single_points.get(ioa)
}

///|
pub fn Outstation::normalized(self : Outstation, ioa : Int) -> Int? {
  self.normalized_values.get(ioa)
}
