///|
/// Counters for protocol throughput and error monitoring.
pub struct FrameMetrics {
  mut frames_encoded : Int
  mut frames_decoded : Int
  mut information_frames : Int
  mut supervisory_frames : Int
  mut unnumbered_frames : Int
  mut bytes_encoded : Int
  mut bytes_decoded : Int
  mut malformed_frames : Int
  mut sequence_errors : Int
  mut service_failures : Int
} derive(Eq, Debug)

///|
pub fn FrameMetrics::new() -> FrameMetrics {
  {
    frames_encoded: 0,
    frames_decoded: 0,
    information_frames: 0,
    supervisory_frames: 0,
    unnumbered_frames: 0,
    bytes_encoded: 0,
    bytes_decoded: 0,
    malformed_frames: 0,
    sequence_errors: 0,
    service_failures: 0,
  }
}

///|
pub fn FrameMetrics::record_encoded(self : FrameMetrics, frame : Frame) -> Unit {
  self.frames_encoded += 1
  self.bytes_encoded += encoded_frame_size(frame)
  match frame.kind {
    Information => self.information_frames += 1
    Supervisory => self.supervisory_frames += 1
    Unnumbered => self.unnumbered_frames += 1
  }
}

///|
pub fn FrameMetrics::record_decoded(self : FrameMetrics, frame : Frame) -> Unit {
  self.frames_decoded += 1
  self.bytes_decoded += encoded_frame_size(frame)
  match frame.kind {
    Information => self.information_frames += 1
    Supervisory => self.supervisory_frames += 1
    Unnumbered => self.unnumbered_frames += 1
  }
}

///|
pub fn FrameMetrics::record_malformed(self : FrameMetrics) -> Unit {
  self.malformed_frames += 1
}

///|
pub fn FrameMetrics::record_sequence_error(self : FrameMetrics) -> Unit {
  self.sequence_errors += 1
}

///|
pub fn FrameMetrics::record_service_failure(self : FrameMetrics) -> Unit {
  self.service_failures += 1
}

///|
pub fn FrameMetrics::total_frames(self : FrameMetrics) -> Int {
  self.frames_encoded + self.frames_decoded
}

///|
pub fn FrameMetrics::total_bytes(self : FrameMetrics) -> Int {
  self.bytes_encoded + self.bytes_decoded
}

///|
pub fn FrameMetrics::error_count(self : FrameMetrics) -> Int {
  self.malformed_frames + self.sequence_errors + self.service_failures
}

///|
pub fn FrameMetrics::success_rate(self : FrameMetrics) -> Float {
  let attempts = self.total_frames() + self.error_count()
  if attempts == 0 {
    1.0
  } else {
    Float::from_int(self.total_frames()) / Float::from_int(attempts)
  }
}

///|
/// Snapshot an evolving metrics object for export or health endpoints.
pub struct MetricsSnapshot {
  frames : Int
  bytes : Int
  errors : Int
  success_rate : Float
} derive(Eq, Debug)

///|
pub fn FrameMetrics::snapshot(self : FrameMetrics) -> MetricsSnapshot {
  {
    frames: self.total_frames(),
    bytes: self.total_bytes(),
    errors: self.error_count(),
    success_rate: self.success_rate(),
  }
}

///|
pub fn MetricsSnapshot::frames(self : MetricsSnapshot) -> Int {
  self.frames
}

///|
pub fn MetricsSnapshot::bytes(self : MetricsSnapshot) -> Int {
  self.bytes
}

///|
pub fn MetricsSnapshot::errors(self : MetricsSnapshot) -> Int {
  self.errors
}

///|
pub fn MetricsSnapshot::success_rate(self : MetricsSnapshot) -> Float {
  self.success_rate
}

///|
/// A trace event with a monotonic timestamp.
pub enum TraceKind {
  FrameSent
  FrameReceived
  StateChanged
  PointUpdated
  ServiceStarted
  ServiceCompleted
  DiagnosticRaised
} derive(Eq, Debug)

///|
pub struct TraceEvent {
  timestamp : Int
  kind : TraceKind
  detail : String
  correlation : Int
} derive(Eq, Debug)

///|
pub fn TraceEvent::new(
  timestamp : Int,
  kind : TraceKind,
  detail : String,
  correlation? : Int = 0,
) -> TraceEvent {
  { timestamp, kind, detail, correlation }
}

///|
pub fn TraceEvent::timestamp(self : TraceEvent) -> Int {
  self.timestamp
}

///|
pub fn TraceEvent::kind(self : TraceEvent) -> TraceKind {
  self.kind
}

///|
pub fn TraceEvent::detail(self : TraceEvent) -> String {
  self.detail
}

///|
pub fn TraceEvent::correlation(self : TraceEvent) -> Int {
  self.correlation
}

///|
pub struct TraceLog {
  events : Array[TraceEvent]
  limit : Int
} derive(Debug)

///|
pub fn TraceLog::new(limit? : Int = 4096) -> Result[TraceLog, String] {
  if limit < 1 {
    Err("trace log limit must be positive")
  } else {
    Ok({ events: [], limit })
  }
}

///|
pub fn TraceLog::push(self : TraceLog, event : TraceEvent) -> Unit {
  self.events.push(event)
  while self.events.length() > self.limit {
    ignore(self.events.remove(0))
  }
}

///|
pub fn TraceLog::len(self : TraceLog) -> Int {
  self.events.length()
}

///|
pub fn TraceLog::all(self : TraceLog) -> Array[TraceEvent] {
  self.events.copy()
}

///|
pub fn TraceLog::since(self : TraceLog, timestamp : Int) -> Array[TraceEvent] {
  let result : Array[TraceEvent] = []
  for event in self.events {
    if event.timestamp() >= timestamp {
      result.push(event)
    }
  }
  result
}

///|
pub fn trace_kind_examples() -> Array[TraceKind] {
  [
    FrameSent,
    FrameReceived,
    StateChanged,
    PointUpdated,
    ServiceStarted,
    ServiceCompleted,
    DiagnosticRaised,
  ]
}

///|
/// Per-byte statistics useful for fixture and link diagnostics.
pub struct ByteStatistics {
  length : Int
  mut zeroes : Int
  mut high_bit : Int
  mut checksum : UInt
  mut minimum : Int
  mut maximum : Int
} derive(Eq, Debug)

///|
pub fn byte_statistics(data : Bytes) -> ByteStatistics {
  let result = {
    length: data.length(),
    zeroes: 0,
    high_bit: 0,
    checksum: 0U,
    minimum: if data.is_empty() {
      0
    } else {
      255
    },
    maximum: 0,
  }
  for byte in data {
    let value = byte.to_int()
    if value == 0 {
      result.zeroes += 1
    }
    if value >= 128 {
      result.high_bit += 1
    }
    result.checksum = (result.checksum + value.reinterpret_as_uint()) &
      0xffffffffU
    if value < result.minimum {
      result.minimum = value
    }
    if value > result.maximum {
      result.maximum = value
    }
  }
  result
}

///|
pub fn ByteStatistics::length(self : ByteStatistics) -> Int {
  self.length
}

///|
pub fn ByteStatistics::zeroes(self : ByteStatistics) -> Int {
  self.zeroes
}

///|
pub fn ByteStatistics::high_bit(self : ByteStatistics) -> Int {
  self.high_bit
}

///|
pub fn ByteStatistics::checksum(self : ByteStatistics) -> UInt {
  self.checksum
}

///|
pub fn ByteStatistics::minimum(self : ByteStatistics) -> Int {
  self.minimum
}

///|
pub fn ByteStatistics::maximum(self : ByteStatistics) -> Int {
  self.maximum
}

///|
/// CRC-16/IBM helper for gateways that wrap IEC APDUs in a framed channel.
pub fn crc16_ibm(data : Bytes) -> UInt {
  let mut crc : UInt = 0xffffU
  for byte in data {
    crc = crc ^ byte.to_int().reinterpret_as_uint()
    for _ in 0..<8 {
      if (crc & 1U) != 0U {
        crc = (crc >> 1) ^ 0xa001U
      } else {
        crc = crc >> 1
      }
    }
  }
  crc
}

///|
/// CRC-32 used by fixture manifests and deterministic transport tests.
pub fn crc32_ieee(data : Bytes) -> UInt {
  let mut crc = 0xffffffffU
  for byte in data {
    crc = crc ^ byte.to_int().reinterpret_as_uint()
    for _ in 0..<8 {
      if (crc & 1U) != 0U {
        crc = (crc >> 1) ^ 0xedb88320U
      } else {
        crc = crc >> 1
      }
    }
  }
  crc ^ 0xffffffffU
}

///|
/// A compact histogram for APDU length distribution.
pub struct LengthHistogram {
  buckets : Map[Int, Int]
  mut samples : Int
} derive(Debug)

///|
pub fn LengthHistogram::new() -> LengthHistogram {
  { buckets: {}, samples: 0 }
}

///|
pub fn LengthHistogram::observe(self : LengthHistogram, length : Int) -> Unit {
  let bucket = if length < 16 {
    16
  } else if length < 32 {
    32
  } else if length < 64 {
    64
  } else if length < 128 {
    128
  } else {
    256
  }
  match self.buckets.get(bucket) {
    Some(value) => self.buckets[bucket] = value + 1
    None => self.buckets[bucket] = 1
  }
  self.samples += 1
}

///|
pub fn LengthHistogram::samples(self : LengthHistogram) -> Int {
  self.samples
}

///|
pub fn LengthHistogram::bucket(self : LengthHistogram, maximum : Int) -> Int {
  match self.buckets.get(maximum) {
    Some(value) => value
    None => 0
  }
}

///|
pub fn LengthHistogram::all(self : LengthHistogram) -> Array[(Int, Int)] {
  let result : Array[(Int, Int)] = []
  for bucket, count in self.buckets {
    result.push((bucket, count))
  }
  result.sort_by((left, right) => left.0 - right.0)
  result
}

///|
/// Record an APDU length observation.
pub fn observe_frame_length(histogram : LengthHistogram, frame : Frame) -> Unit {
  histogram.observe(encoded_frame_size(frame))
}

///|
pub fn diagnostics_examples() -> Array[DiagnosticKind] {
  diagnostic_kind_examples()
}
