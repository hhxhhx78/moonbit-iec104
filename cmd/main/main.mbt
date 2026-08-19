///|
fn main {
  let args = @env.args()
  let mut benchmark = false
  let mut help = false
  for argument in args {
    if argument == "--benchmark" || argument == "benchmark" {
      benchmark = true
    } else if argument == "--help" || argument == "-h" {
      help = true
    }
  }
  if help {
    println("moonbit-iec104 demo CLI")
    println(
      "  moon run cmd/main                 encode a normalized-value I-frame",
    )
    println(
      "  moon run cmd/main -- --benchmark  run the deterministic codec workload",
    )
  } else if benchmark {
    match @iec104.run_benchmark_workload(10000, 16) {
      Err(error) => println("benchmark error: \{error}")
      Ok(result) => {
        println("frames=\{result.encoded_frames()}")
        println("bytes=\{result.encoded_bytes()}")
        println("checksum=\{result.checksum()}")
      }
    }
  } else {
    let payload = @iec104.normalized_value_asdu(3, 1, 2300, 0)
    let frame = @iec104.information_frame(0, 0, payload)
    let encoded = @iec104.encode_frame(frame)
    println("IEC 104 demo: encoded APDU bytes = \{encoded.length()}")
    println("Start with: STARTDT -> I-frame -> S-frame")
  }
}
