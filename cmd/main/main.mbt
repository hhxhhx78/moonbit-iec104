///|
fn main {
  let payload = @iec104.normalized_value_asdu(3, 1, 2300, 0)
  let frame = @iec104.information_frame(0, 0, payload)
  let encoded = @iec104.encode_frame(frame)
  println("IEC 104 demo: encoded APDU bytes = \{encoded.length()}")
  println("Start with: STARTDT -> I-frame -> S-frame")
}
