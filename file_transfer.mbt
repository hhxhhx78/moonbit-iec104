///|
/// State of a bounded IEC 104 file transfer session.
pub enum FileTransferState {
  FileIdle
  FileSelecting
  FileTransferring
  FileWaitingForAck
  FileCompleted
  FileFailed
  FileCancelled
} derive(Eq, Debug)

///|
/// Direction of a file service request.
pub enum FileTransferDirection {
  UploadFile
  DownloadFile
} derive(Eq, Debug)

///|
/// A file identity used by the file service layer.
pub struct FileIdentity {
  station : CommonAddress
  name : String
  file_id : Int
} derive(Eq, Debug)

///|
pub fn FileIdentity::new(
  station : CommonAddress,
  name : String,
  file_id : Int,
) -> Result[FileIdentity, String] {
  if name.length() == 0 || name.length() > 255 {
    Err("file name must contain between 1 and 255 characters")
  } else if file_id < 0 || file_id > 0xffff {
    Err("file id must fit sixteen bits")
  } else {
    Ok({ station, name, file_id })
  }
}

///|
pub fn FileIdentity::station(self : FileIdentity) -> CommonAddress {
  self.station
}

///|
pub fn FileIdentity::name(self : FileIdentity) -> String {
  self.name
}

///|
pub fn FileIdentity::file_id(self : FileIdentity) -> Int {
  self.file_id
}

///|
/// Metadata and immutable content for one locally retained file.
pub struct StoredFile {
  identity : FileIdentity
  data : Bytes
  created_at : Int
  updated_at : Int
  revision : Int
  checksum : UInt
} derive(Eq, Debug)

///|
pub fn StoredFile::new(
  identity : FileIdentity,
  data : Bytes,
  timestamp : Int,
) -> StoredFile {
  {
    identity,
    data,
    created_at: timestamp,
    updated_at: timestamp,
    revision: 1,
    checksum: crc32_ieee(data),
  }
}

///|
pub fn StoredFile::identity(self : StoredFile) -> FileIdentity {
  self.identity
}

///|
pub fn StoredFile::data(self : StoredFile) -> Bytes {
  self.data
}

///|
pub fn StoredFile::size(self : StoredFile) -> Int {
  self.data.length()
}

///|
pub fn StoredFile::created_at(self : StoredFile) -> Int {
  self.created_at
}

///|
pub fn StoredFile::updated_at(self : StoredFile) -> Int {
  self.updated_at
}

///|
pub fn StoredFile::revision(self : StoredFile) -> Int {
  self.revision
}

///|
pub fn StoredFile::checksum(self : StoredFile) -> UInt {
  self.checksum
}

///|
/// Segment of a file containing an offset and an end marker.
pub struct FileSegment {
  file_id : Int
  section : Int
  offset : Int
  data : Bytes
  last : Bool
  checksum : UInt
} derive(Eq, Debug)

///|
pub fn FileSegment::new(
  file_id : Int,
  section : Int,
  offset : Int,
  data : Bytes,
  last : Bool,
) -> Result[FileSegment, String] {
  if file_id < 0 || section < 0 || offset < 0 {
    Err("file segment coordinates cannot be negative")
  } else if data.length() == 0 && !last {
    Err("empty non-terminal file segment is invalid")
  } else {
    Ok({ file_id, section, offset, data, last, checksum: crc32_ieee(data) })
  }
}

///|
pub fn FileSegment::file_id(self : FileSegment) -> Int {
  self.file_id
}

///|
pub fn FileSegment::section(self : FileSegment) -> Int {
  self.section
}

///|
pub fn FileSegment::offset(self : FileSegment) -> Int {
  self.offset
}

///|
pub fn FileSegment::data(self : FileSegment) -> Bytes {
  self.data
}

///|
pub fn FileSegment::last(self : FileSegment) -> Bool {
  self.last
}

///|
pub fn FileSegment::checksum(self : FileSegment) -> UInt {
  self.checksum
}

///|
pub fn FileSegment::valid_checksum(self : FileSegment) -> Bool {
  crc32_ieee(self.data) == self.checksum
}

///|
/// A file inventory entry returned to operational clients.
pub struct FileInventoryEntry {
  identity : FileIdentity
  size : Int
  revision : Int
  checksum : UInt
  updated_at : Int
} derive(Eq, Debug)

///|
pub fn FileInventoryEntry::identity(self : FileInventoryEntry) -> FileIdentity {
  self.identity
}

///|
pub fn FileInventoryEntry::size(self : FileInventoryEntry) -> Int {
  self.size
}

///|
pub fn FileInventoryEntry::revision(self : FileInventoryEntry) -> Int {
  self.revision
}

///|
pub fn FileInventoryEntry::checksum(self : FileInventoryEntry) -> UInt {
  self.checksum
}

///|
pub fn FileInventoryEntry::updated_at(self : FileInventoryEntry) -> Int {
  self.updated_at
}

///|
/// A bounded in-memory store used by outstations and gateway adapters.
pub struct FileStore {
  files : Map[String, StoredFile]
  capacity : Int
  maximum_size : Int
} derive(Debug)

///|
pub fn FileStore::new(
  capacity? : Int = 128,
  maximum_size? : Int = 1048576,
) -> Result[FileStore, String] {
  if capacity < 1 || maximum_size < 1 {
    Err("file store limits must be positive")
  } else {
    Ok({ files: {}, capacity, maximum_size })
  }
}

///|
pub fn FileStore::len(self : FileStore) -> Int {
  self.files.length()
}

///|
pub fn FileStore::capacity(self : FileStore) -> Int {
  self.capacity
}

///|
pub fn FileStore::maximum_size(self : FileStore) -> Int {
  self.maximum_size
}

///|
pub fn FileStore::get(self : FileStore, name : String) -> StoredFile? {
  self.files.get(name)
}

///|
pub fn FileStore::inventory(self : FileStore) -> Array[FileInventoryEntry] {
  let result : Array[FileInventoryEntry] = []
  for _, file in self.files {
    result.push({
      identity: file.identity(),
      size: file.size(),
      revision: file.revision(),
      checksum: file.checksum(),
      updated_at: file.updated_at(),
    })
  }
  result.sort_by((left, right) => {
    if left.identity().station().number() != right.identity().station().number() {
      left.identity().station().number() - right.identity().station().number()
    } else {
      left.identity().name().compare(right.identity().name())
    }
  })
  result
}

///|
pub fn FileStore::put(
  self : FileStore,
  identity : FileIdentity,
  data : Bytes,
  timestamp : Int,
) -> Result[StoredFile, String] {
  if data.length() > self.maximum_size {
    Err("file exceeds configured maximum size")
  } else if self.files.length() >= self.capacity &&
    self.files.get(identity.name()) is None {
    Err("file store capacity is full")
  } else {
    let file = match self.files.get(identity.name()) {
      Some(existing) =>
        {
          identity,
          data,
          created_at: existing.created_at(),
          updated_at: timestamp,
          revision: existing.revision() + 1,
          checksum: crc32_ieee(data),
        }
      None => StoredFile::new(identity, data, timestamp)
    }
    self.files[file.identity().name()] = file
    Ok(file)
  }
}

///|
pub fn FileStore::remove(
  self : FileStore,
  name : String,
) -> Result[StoredFile, String] {
  match self.files.get(name) {
    None => Err("file does not exist")
    Some(file) => {
      self.files.remove(name)
      Ok(file)
    }
  }
}

///|
/// File transfer session with ordered segment assembly.
pub struct FileTransferSession {
  ticket : Int
  identity : FileIdentity
  direction : FileTransferDirection
  expected_size : Int
  segment_size : Int
  expected_checksum : UInt?
  buffer : Array[Byte]
  mut next_offset : Int
  mut next_section : Int
  mut state : FileTransferState
  mut attempts : Int
  mut last_activity : Int
  mut error : String
} derive(Debug)

///|
pub fn FileTransferSession::new(
  ticket : Int,
  identity : FileIdentity,
  direction : FileTransferDirection,
  expected_size : Int,
  segment_size : Int,
  expected_checksum : UInt?,
  timestamp : Int,
) -> Result[FileTransferSession, String] {
  if ticket < 1 || expected_size < 0 {
    Err("file transfer ticket and size must be non-negative")
  } else if segment_size < 1 || segment_size > 240 {
    Err("file segment size must be between 1 and 240 bytes")
  } else {
    Ok({
      ticket,
      identity,
      direction,
      expected_size,
      segment_size,
      expected_checksum,
      buffer: [],
      next_offset: 0,
      next_section: 0,
      state: FileSelecting,
      attempts: 0,
      last_activity: timestamp,
      error: "",
    })
  }
}

///|
pub fn FileTransferSession::ticket(self : FileTransferSession) -> Int {
  self.ticket
}

///|
pub fn FileTransferSession::identity(
  self : FileTransferSession,
) -> FileIdentity {
  self.identity
}

///|
pub fn FileTransferSession::direction(
  self : FileTransferSession,
) -> FileTransferDirection {
  self.direction
}

///|
pub fn FileTransferSession::expected_size(self : FileTransferSession) -> Int {
  self.expected_size
}

///|
pub fn FileTransferSession::segment_size(self : FileTransferSession) -> Int {
  self.segment_size
}

///|
pub fn FileTransferSession::expected_checksum(
  self : FileTransferSession,
) -> UInt? {
  self.expected_checksum
}

///|
pub fn FileTransferSession::received_size(self : FileTransferSession) -> Int {
  self.buffer.length()
}

///|
pub fn FileTransferSession::next_offset(self : FileTransferSession) -> Int {
  self.next_offset
}

///|
pub fn FileTransferSession::next_section(self : FileTransferSession) -> Int {
  self.next_section
}

///|
pub fn FileTransferSession::state(
  self : FileTransferSession,
) -> FileTransferState {
  self.state
}

///|
pub fn FileTransferSession::attempts(self : FileTransferSession) -> Int {
  self.attempts
}

///|
pub fn FileTransferSession::last_activity(self : FileTransferSession) -> Int {
  self.last_activity
}

///|
pub fn FileTransferSession::error(self : FileTransferSession) -> String {
  self.error
}

///|
pub fn FileTransferSession::data(self : FileTransferSession) -> Bytes {
  Bytes::from_array(self.buffer.copy())
}

///|
pub fn FileTransferSession::activate(
  self : FileTransferSession,
  timestamp : Int,
) -> Result[Unit, String] {
  if self.state != FileSelecting {
    Err("file session is not selectable")
  } else {
    self.state = FileTransferring
    self.last_activity = timestamp
    Ok(())
  }
}

///|
pub fn FileTransferSession::append(
  self : FileTransferSession,
  segment : FileSegment,
  timestamp : Int,
) -> Result[Unit, String] {
  if self.state != FileTransferring && self.state != FileWaitingForAck {
    return Err("file session is not receiving segments")
  }
  if segment.file_id() != self.identity.file_id() {
    return Err("file segment belongs to another file")
  }
  if segment.section() != self.next_section ||
    segment.offset() != self.next_offset {
    return Err("file segment is out of order")
  }
  if !segment.valid_checksum() {
    return Err("file segment checksum mismatch")
  }
  if self.received_size() + segment.data().length() > self.expected_size {
    return Err("file transfer exceeds expected size")
  }
  for byte in segment.data().to_array() {
    self.buffer.push(byte)
  }
  self.next_offset += segment.data().length()
  self.next_section += 1
  self.last_activity = timestamp
  self.attempts += 1
  if segment.last() {
    if self.received_size() != self.expected_size {
      self.state = FileFailed
      self.error = "terminal segment has unexpected size"
      Err(self.error)
    } else {
      self.state = FileCompleted
      Ok(())
    }
  } else {
    self.state = FileWaitingForAck
    Ok(())
  }
}

///|
pub fn FileTransferSession::ack(
  self : FileTransferSession,
  timestamp : Int,
) -> Result[Unit, String] {
  if self.state != FileWaitingForAck {
    Err("file session is not waiting for acknowledgement")
  } else {
    self.state = FileTransferring
    self.last_activity = timestamp
    Ok(())
  }
}

///|
pub fn FileTransferSession::fail(
  self : FileTransferSession,
  timestamp : Int,
  message : String,
) -> Unit {
  self.state = FileFailed
  self.last_activity = timestamp
  self.error = message
}

///|
pub fn FileTransferSession::cancel(
  self : FileTransferSession,
  timestamp : Int,
) -> Result[Unit, String] {
  if self.state == FileCompleted || self.state == FileFailed {
    Err("terminal file session cannot be cancelled")
  } else {
    self.state = FileCancelled
    self.last_activity = timestamp
    Ok(())
  }
}

///|
/// Generate ordered download segments from an immutable file.
pub fn split_file_segments(
  file : StoredFile,
  segment_size : Int,
) -> Result[Array[FileSegment], String] {
  if segment_size < 1 || segment_size > 240 {
    return Err("file segment size is outside 1..240")
  }
  let bytes = file.data().to_array()
  let result : Array[FileSegment] = []
  if bytes.length() == 0 {
    match FileSegment::new(file.identity().file_id(), 0, 0, b"", true) {
      Ok(segment) => result.push(segment)
      Err(_) => ()
    }
  } else {
    let mut offset = 0
    let mut section = 0
    while offset < bytes.length() {
      let end = if offset + segment_size > bytes.length() {
        bytes.length()
      } else {
        offset + segment_size
      }
      let last = end == bytes.length()
      match
        FileSegment::new(
          file.identity().file_id(),
          section,
          offset,
          Bytes::from_array(bytes[offset:end]),
          last,
        ) {
        Ok(segment) => result.push(segment)
        Err(error) => return Err(error)
      }
      offset = end
      section += 1
    }
  }
  Ok(result)
}

///|
/// Counters for file service throughput and failures.
pub struct FileTransferMetrics {
  mut sessions : Int
  mut completed : Int
  mut failed : Int
  mut cancelled : Int
  mut segments : Int
  mut bytes : Int
} derive(Eq, Debug)

///|
pub fn FileTransferMetrics::new() -> FileTransferMetrics {
  { sessions: 0, completed: 0, failed: 0, cancelled: 0, segments: 0, bytes: 0 }
}

///|
pub fn FileTransferMetrics::sessions(self : FileTransferMetrics) -> Int {
  self.sessions
}

///|
pub fn FileTransferMetrics::completed(self : FileTransferMetrics) -> Int {
  self.completed
}

///|
pub fn FileTransferMetrics::failed(self : FileTransferMetrics) -> Int {
  self.failed
}

///|
pub fn FileTransferMetrics::cancelled(self : FileTransferMetrics) -> Int {
  self.cancelled
}

///|
pub fn FileTransferMetrics::segments(self : FileTransferMetrics) -> Int {
  self.segments
}

///|
pub fn FileTransferMetrics::bytes(self : FileTransferMetrics) -> Int {
  self.bytes
}

///|
/// File service coordinator for stores and station sessions.
pub struct FileTransferManager {
  store : FileStore
  sessions : Map[Int, FileTransferSession]
  history : Array[FileTransferSession]
  history_limit : Int
  mut next_ticket : Int
  metrics : FileTransferMetrics
} derive(Debug)

///|
pub fn FileTransferManager::new(
  store : FileStore,
  history_limit? : Int = 1024,
) -> Result[FileTransferManager, String] {
  if history_limit < 1 {
    Err("file transfer history limit must be positive")
  } else {
    Ok({
      store,
      sessions: {},
      history: [],
      history_limit,
      next_ticket: 1,
      metrics: FileTransferMetrics::new(),
    })
  }
}

///|
pub fn FileTransferManager::store(self : FileTransferManager) -> FileStore {
  self.store
}

///|
pub fn FileTransferManager::metrics(
  self : FileTransferManager,
) -> FileTransferMetrics {
  self.metrics
}

///|
pub fn FileTransferManager::session_count(self : FileTransferManager) -> Int {
  self.sessions.length()
}

///|
pub fn FileTransferManager::history(
  self : FileTransferManager,
) -> Array[FileTransferSession] {
  self.history.copy()
}

///|
pub fn FileTransferManager::get(
  self : FileTransferManager,
  ticket : Int,
) -> FileTransferSession? {
  self.sessions.get(ticket)
}

///|
pub fn FileTransferManager::begin_upload(
  self : FileTransferManager,
  identity : FileIdentity,
  expected_size : Int,
  expected_checksum? : UInt,
  segment_size? : Int = 240,
  timestamp? : Int = 0,
) -> Result[FileTransferSession, String] {
  match
    FileTransferSession::new(
      self.next_ticket,
      identity,
      UploadFile,
      expected_size,
      segment_size,
      expected_checksum,
      timestamp,
    ) {
    Err(error) => Err(error)
    Ok(session) => {
      self.sessions[session.ticket()] = session
      self.next_ticket += 1
      self.metrics.sessions += 1
      Ok(session)
    }
  }
}

///|
pub fn FileTransferManager::begin_download(
  self : FileTransferManager,
  identity : FileIdentity,
  segment_size? : Int = 240,
  timestamp? : Int = 0,
) -> Result[Array[FileSegment], String] {
  ignore(timestamp)
  match self.store.get(identity.name()) {
    None => Err("file does not exist")
    Some(file) => split_file_segments(file, segment_size)
  }
}

///|
pub fn FileTransferManager::activate(
  self : FileTransferManager,
  ticket : Int,
  timestamp : Int,
) -> Result[Unit, String] {
  match self.sessions.get(ticket) {
    None => Err("unknown file session")
    Some(session) =>
      match session.activate(timestamp) {
        Ok(_) => {
          self.sessions[ticket] = session
          Ok(())
        }
        Err(error) => Err(error)
      }
  }
}

///|
pub fn FileTransferManager::append(
  self : FileTransferManager,
  ticket : Int,
  segment : FileSegment,
  timestamp : Int,
) -> Result[FileTransferState, String] {
  match self.sessions.get(ticket) {
    None => Err("unknown file session")
    Some(session) =>
      match session.append(segment, timestamp) {
        Err(error) => {
          session.fail(timestamp, error)
          self.sessions[ticket] = session
          self.metrics.failed += 1
          Err(session.error())
        }
        Ok(_) => {
          self.sessions[ticket] = session
          self.metrics.segments += 1
          self.metrics.bytes += segment.data().length()
          if session.state() == FileCompleted {
            self.metrics.completed += 1
          }
          Ok(session.state())
        }
      }
  }
}

///|
pub fn FileTransferManager::ack(
  self : FileTransferManager,
  ticket : Int,
  timestamp : Int,
) -> Result[Unit, String] {
  match self.sessions.get(ticket) {
    None => Err("unknown file session")
    Some(session) =>
      match session.ack(timestamp) {
        Ok(_) => {
          self.sessions[ticket] = session
          Ok(())
        }
        Err(error) => Err(error)
      }
  }
}

///|
pub fn FileTransferManager::finish(
  self : FileTransferManager,
  ticket : Int,
  timestamp : Int,
) -> Result[StoredFile, String] {
  match self.sessions.get(ticket) {
    None => Err("unknown file session")
    Some(session) =>
      if session.state() != FileCompleted {
        Err("file session is not complete")
      } else {
        match self.store.put(session.identity(), session.data(), timestamp) {
          Ok(file) => {
            self.sessions.remove(ticket)
            self.history.push(session)
            while self.history.length() > self.history_limit {
              ignore(self.history.remove(0))
            }
            Ok(file)
          }
          Err(error) => Err(error)
        }
      }
  }
}

///|
pub fn FileTransferManager::cancel(
  self : FileTransferManager,
  ticket : Int,
  timestamp : Int,
) -> Result[Unit, String] {
  match self.sessions.get(ticket) {
    None => Err("unknown file session")
    Some(session) =>
      match session.cancel(timestamp) {
        Ok(_) => {
          self.sessions.remove(ticket)
          self.history.push(session)
          self.metrics.cancelled += 1
          Ok(())
        }
        Err(error) => Err(error)
      }
  }
}

///|
pub fn file_transfer_state_examples() -> Array[FileTransferState] {
  [
    FileIdle,
    FileSelecting,
    FileTransferring,
    FileWaitingForAck,
    FileCompleted,
    FileFailed,
    FileCancelled,
  ]
}

///|
pub fn file_transfer_direction_examples() -> Array[FileTransferDirection] {
  [UploadFile, DownloadFile]
}
