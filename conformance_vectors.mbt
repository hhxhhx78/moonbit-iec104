///|
/// Vector category used by the protocol regression runner.
pub enum VectorCategory {
  ApciVector
  AsduVector
  SequenceVector
  BoundaryVector
  NegativeVector
} derive(Eq, Debug)

///|
/// Expected outcome of a conformance vector.
pub enum VectorExpectation {
  ExpectDecode
  ExpectReject
} derive(Eq, Debug)

///|
/// A deterministic byte-level protocol vector.
pub struct ConformanceVector {
  name : String
  category : VectorCategory
  input : Bytes
  expectation : VectorExpectation
  expected_kind : FrameKind?
  expected_send : Int?
  expected_receive : Int?
  expected_payload : Bytes?
} derive(Debug)

///|
pub fn ConformanceVector::new(
  name : String,
  category : VectorCategory,
  input : Bytes,
  expectation : VectorExpectation,
  expected_kind? : FrameKind,
  expected_send? : Int,
  expected_receive? : Int,
  expected_payload? : Bytes,
) -> Result[ConformanceVector, String] {
  if name.length() == 0 {
    Err("conformance vector name is empty")
  } else {
    Ok({
      name,
      category,
      input,
      expectation,
      expected_kind,
      expected_send,
      expected_receive,
      expected_payload,
    })
  }
}

///|
pub fn ConformanceVector::name(self : ConformanceVector) -> String {
  self.name
}

///|
pub fn ConformanceVector::category(self : ConformanceVector) -> VectorCategory {
  self.category
}

///|
pub fn ConformanceVector::input(self : ConformanceVector) -> Bytes {
  self.input
}

///|
pub fn ConformanceVector::expectation(
  self : ConformanceVector,
) -> VectorExpectation {
  self.expectation
}

///|
pub fn ConformanceVector::expected_kind(self : ConformanceVector) -> FrameKind? {
  self.expected_kind
}

///|
pub fn ConformanceVector::expected_send(self : ConformanceVector) -> Int? {
  self.expected_send
}

///|
pub fn ConformanceVector::expected_receive(self : ConformanceVector) -> Int? {
  self.expected_receive
}

///|
pub fn ConformanceVector::expected_payload(self : ConformanceVector) -> Bytes? {
  self.expected_payload
}

///|
/// Diagnostic detail produced for a vector failure.
pub struct VectorMismatch {
  vector : String
  field : String
  expected : String
  actual : String
} derive(Eq, Debug)

///|
pub fn VectorMismatch::vector(self : VectorMismatch) -> String {
  self.vector
}

///|
pub fn VectorMismatch::field(self : VectorMismatch) -> String {
  self.field
}

///|
pub fn VectorMismatch::expected(self : VectorMismatch) -> String {
  self.expected
}

///|
pub fn VectorMismatch::actual(self : VectorMismatch) -> String {
  self.actual
}

///|
pub struct VectorResult {
  name : String
  passed : Bool
  decoded : Bool
  encoded_size : Int
  mismatches : Array[VectorMismatch]
  message : String
} derive(Debug)

///|
pub fn VectorResult::name(self : VectorResult) -> String {
  self.name
}

///|
pub fn VectorResult::passed(self : VectorResult) -> Bool {
  self.passed
}

///|
pub fn VectorResult::decoded(self : VectorResult) -> Bool {
  self.decoded
}

///|
pub fn VectorResult::encoded_size(self : VectorResult) -> Int {
  self.encoded_size
}

///|
pub fn VectorResult::mismatches(self : VectorResult) -> Array[VectorMismatch] {
  self.mismatches.copy()
}

///|
pub fn VectorResult::message(self : VectorResult) -> String {
  self.message
}

///|
pub struct VectorReport {
  total : Int
  passed : Int
  failed : Int
  rejected : Int
  bytes : Int
  results : Array[VectorResult]
} derive(Debug)

///|
pub fn VectorReport::total(self : VectorReport) -> Int {
  self.total
}

///|
pub fn VectorReport::passed(self : VectorReport) -> Int {
  self.passed
}

///|
pub fn VectorReport::failed(self : VectorReport) -> Int {
  self.failed
}

///|
pub fn VectorReport::rejected(self : VectorReport) -> Int {
  self.rejected
}

///|
pub fn VectorReport::bytes(self : VectorReport) -> Int {
  self.bytes
}

///|
pub fn VectorReport::results(self : VectorReport) -> Array[VectorResult] {
  self.results.copy()
}

///|
fn vector_frame_kind_name(kind : FrameKind) -> String {
  match kind {
    Information => "I"
    Supervisory => "S"
    Unnumbered => "U"
  }
}

///|
fn mismatch(
  vector : ConformanceVector,
  field : String,
  expected : String,
  actual : String,
) -> VectorMismatch {
  { vector: vector.name(), field, expected, actual }
}

///|
fn validate_decoded(
  vector : ConformanceVector,
  frame : Frame,
) -> Array[VectorMismatch] {
  let result : Array[VectorMismatch] = []
  match vector.expected_kind() {
    Some(kind) =>
      if frame.kind != kind {
        result.push(
          mismatch(
            vector,
            "kind",
            vector_frame_kind_name(kind),
            vector_frame_kind_name(frame.kind),
          ),
        )
      }
    None => ()
  }
  match vector.expected_send() {
    Some(value) =>
      if frame.send_sequence != value {
        result.push(
          mismatch(vector, "send-sequence", "{value}", "{frame.send_sequence}"),
        )
      }
    None => ()
  }
  match vector.expected_receive() {
    Some(value) =>
      if frame.receive_sequence != value {
        result.push(
          mismatch(
            vector, "receive-sequence", "{value}", "{frame.receive_sequence}",
          ),
        )
      }
    None => ()
  }
  match vector.expected_payload() {
    Some(value) =>
      if frame.payload != value {
        result.push(
          mismatch(
            vector, "payload", "{value.length()} bytes", "{frame.payload.length()} bytes",
          ),
        )
      }
    None => ()
  }
  result
}

///|
pub fn run_conformance_vector(vector : ConformanceVector) -> VectorResult {
  match decode_frame(vector.input()) {
    Err(error) => {
      let passed = vector.expectation() == ExpectReject
      {
        name: vector.name(),
        passed,
        decoded: false,
        encoded_size: 0,
        mismatches: if passed {
          []
        } else {
          [mismatch(vector, "decode", "valid APDU", error)]
        },
        message: if passed {
          "expected rejection"
        } else {
          error
        },
      }
    }
    Ok(frame) => {
      let mismatches = if vector.expectation() == ExpectReject {
        [mismatch(vector, "decode", "rejected", "decoded")]
      } else {
        validate_decoded(vector, frame)
      }
      let encoded = encode_frame(frame)
      let roundtrip = if encoded == vector.input() {
        mismatches
      } else {
        let result = mismatches.copy()
        result.push(
          mismatch(
            vector, "roundtrip", "identical APDU", "encoded bytes differ",
          ),
        )
        result
      }
      {
        name: vector.name(),
        passed: roundtrip.length() == 0,
        decoded: true,
        encoded_size: encoded.length(),
        mismatches: roundtrip,
        message: if roundtrip.length() == 0 {
          "vector passed"
        } else {
          "vector mismatch"
        },
      }
    }
  }
}

///|
pub fn run_conformance_suite(
  vectors : Array[ConformanceVector],
) -> VectorReport {
  let results : Array[VectorResult] = []
  let mut passed = 0
  let mut failed = 0
  let mut rejected = 0
  let mut bytes = 0
  for vector in vectors {
    let result = run_conformance_vector(vector)
    results.push(result)
    bytes += result.encoded_size()
    if result.passed() {
      passed += 1
    } else {
      failed += 1
    }
    if !result.decoded() {
      rejected += 1
    }
  }
  { total: vectors.length(), passed, failed, rejected, bytes, results }
}

///|
fn vector_ok(
  name : String,
  category : VectorCategory,
  frame : Frame,
) -> ConformanceVector {
  ConformanceVector::new(
    name,
    category,
    encode_frame(frame),
    ExpectDecode,
    expected_kind=frame.kind,
    expected_send=frame.send_sequence,
    expected_receive=frame.receive_sequence,
    expected_payload=frame.payload,
  ).unwrap()
}

///|
fn vector_reject(name : String, input : Bytes) -> ConformanceVector {
  ConformanceVector::new(name, NegativeVector, input, ExpectReject).unwrap()
}

///|
/// Built-in vectors cover all APCI frame families and malformed boundaries.
pub fn standard_conformance_vectors() -> Array[ConformanceVector] {
  let normalized = normalized_value_asdu(3, 1, 2300, 0)
  let single = single_point_asdu(3, 1, 7, true, 0)
  [
    vector_ok("i-frame-empty-payload", ApciVector, information_frame(0, 0, b"")),
    vector_ok(
      "i-frame-sequence-wrap",
      SequenceVector,
      information_frame(32767, 32767, normalized),
    ),
    vector_ok(
      "i-frame-single-point",
      AsduVector,
      information_frame(12, 9, single),
    ),
    vector_ok("s-frame-zero", ApciVector, supervisory_frame(0)),
    vector_ok("s-frame-window-edge", SequenceVector, supervisory_frame(32767)),
    vector_ok("u-startdt", ApciVector, unnumbered_frame(0x0007U.to_uint16())),
    vector_ok("u-stopdt", ApciVector, unnumbered_frame(0x0013U.to_uint16())),
    vector_ok("u-testfr", ApciVector, unnumbered_frame(0x0043U.to_uint16())),
    vector_reject("short-apdu", b"\x68\x04"),
    vector_reject("wrong-start-byte", b"\x67\x04\x00\x00\x00\x00"),
    vector_reject("declared-length-too-long", b"\x68\x08\x00\x00\x00\x00"),
  ]
}

///|
/// Add a caller-owned vector while preserving deterministic ordering.
pub struct VectorCatalog {
  vectors : Array[ConformanceVector]
  names : Map[String, Bool]
} derive(Debug)

///|
pub fn VectorCatalog::new() -> VectorCatalog {
  { vectors: [], names: {} }
}

///|
pub fn VectorCatalog::add(
  self : VectorCatalog,
  vector : ConformanceVector,
) -> Result[Unit, String] {
  if self.names.contains(vector.name()) {
    Err("conformance vector name already exists")
  } else {
    self.names[vector.name()] = true
    self.vectors.push(vector)
    Ok(())
  }
}

///|
pub fn VectorCatalog::add_all(
  self : VectorCatalog,
  vectors : Array[ConformanceVector],
) -> Result[Unit, String] {
  for vector in vectors {
    match self.add(vector) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  Ok(())
}

///|
pub fn VectorCatalog::len(self : VectorCatalog) -> Int {
  self.vectors.length()
}

///|
pub fn VectorCatalog::vectors(self : VectorCatalog) -> Array[ConformanceVector] {
  self.vectors.copy()
}

///|
pub fn vector_category_examples() -> Array[VectorCategory] {
  [ApciVector, AsduVector, SequenceVector, BoundaryVector, NegativeVector]
}

///|
pub fn vector_expectation_examples() -> Array[VectorExpectation] {
  [ExpectDecode, ExpectReject]
}
