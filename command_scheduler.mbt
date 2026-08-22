///|
/// Priority used by the deterministic command scheduler.
pub enum CommandPriority {
  EmergencyPriority
  HighPriority
  NormalPriority
  LowPriority
} derive(Eq, Debug)

///|
pub fn CommandPriority::weight(self : CommandPriority) -> Int {
  match self {
    EmergencyPriority => 0
    HighPriority => 1
    NormalPriority => 2
    LowPriority => 3
  }
}

///|
/// Lifecycle state of a command ticket.
pub enum CommandLifecycle {
  QueuedCommand
  DispatchedCommand
  AwaitingConfirmation
  CompletedCommand
  FailedCommand
  RejectedCommand
  ExpiredCommand
  CancelledCommand
} derive(Eq, Debug)

///|
/// Retry and timeout policy for a command family.
pub struct RetryPolicy {
  max_attempts : Int
  timeout : Int
  backoff : Int
  retry_rejected : Bool
} derive(Eq, Debug)

///|
pub fn RetryPolicy::new(
  max_attempts? : Int = 3,
  timeout? : Int = 10,
  backoff? : Int = 2,
  retry_rejected? : Bool = false,
) -> Result[RetryPolicy, String] {
  if max_attempts < 1 || max_attempts > 32 {
    Err("command retry attempts must be between 1 and 32")
  } else if timeout < 1 || timeout > 86400 {
    Err("command timeout must be between 1 and 86400 seconds")
  } else if backoff < 0 || backoff > 86400 {
    Err("command retry backoff must be between 0 and 86400 seconds")
  } else {
    Ok({ max_attempts, timeout, backoff, retry_rejected })
  }
}

///|
pub fn RetryPolicy::max_attempts(self : RetryPolicy) -> Int {
  self.max_attempts
}

///|
pub fn RetryPolicy::timeout(self : RetryPolicy) -> Int {
  self.timeout
}

///|
pub fn RetryPolicy::backoff(self : RetryPolicy) -> Int {
  self.backoff
}

///|
pub fn RetryPolicy::retry_rejected(self : RetryPolicy) -> Bool {
  self.retry_rejected
}

///|
/// A command request admitted to the scheduler.
pub struct CommandRequest {
  ticket : Int
  station : CommonAddress
  object : ApplicationObject
  priority : CommandPriority
  submitted_at : Int
  deadline : Int
  idempotency_key : String
  source : String
  policy : RetryPolicy
  mut attempts : Int
  mut lifecycle : CommandLifecycle
  mut next_attempt_at : Int
  mut last_error : String
} derive(Debug)

///|
pub fn CommandRequest::new(
  ticket : Int,
  station : CommonAddress,
  object : ApplicationObject,
  priority : CommandPriority,
  submitted_at : Int,
  deadline : Int,
  idempotency_key : String,
  source : String,
  policy : RetryPolicy,
) -> Result[CommandRequest, Diagnostic] {
  if ticket < 1 {
    Err(Diagnostic::new(InvalidQualifier, "command ticket must be positive"))
  } else if deadline < submitted_at {
    Err(Diagnostic::new(TimerExpired, "command deadline precedes submission"))
  } else if idempotency_key.length() == 0 {
    Err(Diagnostic::new(InvalidQualifier, "command idempotency key is empty"))
  } else if !object.is_command() {
    Err(Diagnostic::new(InvalidType, "scheduler accepts control objects only"))
  } else {
    Ok({
      ticket,
      station,
      object,
      priority,
      submitted_at,
      deadline,
      idempotency_key,
      source,
      policy,
      attempts: 0,
      lifecycle: QueuedCommand,
      next_attempt_at: submitted_at,
      last_error: "",
    })
  }
}

///|
pub fn CommandRequest::ticket(self : CommandRequest) -> Int {
  self.ticket
}

///|
pub fn CommandRequest::station(self : CommandRequest) -> CommonAddress {
  self.station
}

///|
pub fn CommandRequest::object(self : CommandRequest) -> ApplicationObject {
  self.object
}

///|
pub fn CommandRequest::priority(self : CommandRequest) -> CommandPriority {
  self.priority
}

///|
pub fn CommandRequest::submitted_at(self : CommandRequest) -> Int {
  self.submitted_at
}

///|
pub fn CommandRequest::deadline(self : CommandRequest) -> Int {
  self.deadline
}

///|
pub fn CommandRequest::idempotency_key(self : CommandRequest) -> String {
  self.idempotency_key
}

///|
pub fn CommandRequest::source(self : CommandRequest) -> String {
  self.source
}

///|
pub fn CommandRequest::policy(self : CommandRequest) -> RetryPolicy {
  self.policy
}

///|
pub fn CommandRequest::attempts(self : CommandRequest) -> Int {
  self.attempts
}

///|
pub fn CommandRequest::lifecycle(self : CommandRequest) -> CommandLifecycle {
  self.lifecycle
}

///|
pub fn CommandRequest::next_attempt_at(self : CommandRequest) -> Int {
  self.next_attempt_at
}

///|
pub fn CommandRequest::last_error(self : CommandRequest) -> String {
  self.last_error
}

///|
/// A transition emitted by the scheduler for audit and UI consumers.
pub struct CommandAudit {
  ticket : Int
  timestamp : Int
  from : CommandLifecycle
  to : CommandLifecycle
  attempt : Int
  message : String
} derive(Eq, Debug)

///|
pub fn CommandAudit::new(
  ticket : Int,
  timestamp : Int,
  from : CommandLifecycle,
  to : CommandLifecycle,
  attempt : Int,
  message : String,
) -> CommandAudit {
  { ticket, timestamp, from, to, attempt, message }
}

///|
pub fn CommandAudit::ticket(self : CommandAudit) -> Int {
  self.ticket
}

///|
pub fn CommandAudit::timestamp(self : CommandAudit) -> Int {
  self.timestamp
}

///|
pub fn CommandAudit::from(self : CommandAudit) -> CommandLifecycle {
  self.from
}

///|
pub fn CommandAudit::to(self : CommandAudit) -> CommandLifecycle {
  self.to
}

///|
pub fn CommandAudit::attempt(self : CommandAudit) -> Int {
  self.attempt
}

///|
pub fn CommandAudit::message(self : CommandAudit) -> String {
  self.message
}

///|
/// Scheduler counters exposed to operational metrics.
pub struct SchedulerMetrics {
  mut accepted : Int
  mut duplicates : Int
  mut rejected : Int
  mut dispatched : Int
  mut completed : Int
  mut failed : Int
  mut expired : Int
  mut cancelled : Int
  mut retried : Int
} derive(Eq, Debug)

///|
pub fn SchedulerMetrics::new() -> SchedulerMetrics {
  {
    accepted: 0,
    duplicates: 0,
    rejected: 0,
    dispatched: 0,
    completed: 0,
    failed: 0,
    expired: 0,
    cancelled: 0,
    retried: 0,
  }
}

///|
pub fn SchedulerMetrics::accepted(self : SchedulerMetrics) -> Int {
  self.accepted
}

///|
pub fn SchedulerMetrics::duplicates(self : SchedulerMetrics) -> Int {
  self.duplicates
}

///|
pub fn SchedulerMetrics::rejected(self : SchedulerMetrics) -> Int {
  self.rejected
}

///|
pub fn SchedulerMetrics::dispatched(self : SchedulerMetrics) -> Int {
  self.dispatched
}

///|
pub fn SchedulerMetrics::completed(self : SchedulerMetrics) -> Int {
  self.completed
}

///|
pub fn SchedulerMetrics::failed(self : SchedulerMetrics) -> Int {
  self.failed
}

///|
pub fn SchedulerMetrics::expired(self : SchedulerMetrics) -> Int {
  self.expired
}

///|
pub fn SchedulerMetrics::cancelled(self : SchedulerMetrics) -> Int {
  self.cancelled
}

///|
pub fn SchedulerMetrics::retried(self : SchedulerMetrics) -> Int {
  self.retried
}

///|
/// A dispatch result containing the ticket and object to encode on the wire.
pub struct CommandDispatch {
  ticket : Int
  station : CommonAddress
  object : ApplicationObject
  attempt : Int
  expires_at : Int
} derive(Debug)

///|
pub fn CommandDispatch::ticket(self : CommandDispatch) -> Int {
  self.ticket
}

///|
pub fn CommandDispatch::station(self : CommandDispatch) -> CommonAddress {
  self.station
}

///|
pub fn CommandDispatch::object(self : CommandDispatch) -> ApplicationObject {
  self.object
}

///|
pub fn CommandDispatch::attempt(self : CommandDispatch) -> Int {
  self.attempt
}

///|
pub fn CommandDispatch::expires_at(self : CommandDispatch) -> Int {
  self.expires_at
}

///|
/// Deterministic command scheduler with idempotency and retry handling.
pub struct CommandScheduler {
  pending : Array[CommandRequest]
  audits : Array[CommandAudit]
  audit_limit : Int
  idempotency : Map[String, Int]
  mut next_ticket : Int
  metrics : SchedulerMetrics
} derive(Debug)

///|
pub fn CommandScheduler::new(
  audit_limit? : Int = 4096,
) -> Result[CommandScheduler, String] {
  if audit_limit < 1 {
    Err("command audit limit must be positive")
  } else {
    Ok({
      pending: [],
      audits: [],
      audit_limit,
      idempotency: {},
      next_ticket: 1,
      metrics: SchedulerMetrics::new(),
    })
  }
}

///|
pub fn CommandScheduler::metrics(self : CommandScheduler) -> SchedulerMetrics {
  self.metrics
}

///|
pub fn CommandScheduler::pending_count(self : CommandScheduler) -> Int {
  let mut count = 0
  for request in self.pending {
    if request.lifecycle() == QueuedCommand ||
      request.lifecycle() == AwaitingConfirmation {
      count += 1
    }
  }
  count
}

///|
pub fn CommandScheduler::audits(self : CommandScheduler) -> Array[CommandAudit] {
  self.audits.copy()
}

///|
fn CommandScheduler::audit(
  self : CommandScheduler,
  ticket : Int,
  timestamp : Int,
  from : CommandLifecycle,
  to : CommandLifecycle,
  attempt : Int,
  message : String,
) -> Unit {
  self.audits.push(
    CommandAudit::new(ticket, timestamp, from, to, attempt, message),
  )
  while self.audits.length() > self.audit_limit {
    ignore(self.audits.remove(0))
  }
}

///|
fn scheduler_candidate(left : CommandRequest, right : CommandRequest) -> Int {
  let priority = left.priority().weight() - right.priority().weight()
  if priority != 0 {
    priority
  } else {
    let deadline = left.deadline() - right.deadline()
    if deadline != 0 {
      deadline
    } else {
      left.ticket() - right.ticket()
    }
  }
}

///|
pub fn CommandScheduler::submit(
  self : CommandScheduler,
  station : CommonAddress,
  object : ApplicationObject,
  priority : CommandPriority,
  now : Int,
  deadline : Int,
  idempotency_key : String,
  source? : String = "operator",
  policy? : RetryPolicy = RetryPolicy::new().unwrap(),
) -> Result[CommandRequest, Diagnostic] {
  if self.idempotency.contains(idempotency_key) {
    self.metrics.duplicates += 1
    return Err(
      Diagnostic::new(InvalidQualifier, "duplicate command idempotency key"),
    )
  }
  match
    CommandRequest::new(
      self.next_ticket,
      station,
      object,
      priority,
      now,
      deadline,
      idempotency_key,
      source,
      policy,
    ) {
    Err(error) => {
      self.metrics.rejected += 1
      Err(error)
    }
    Ok(request) => {
      self.idempotency[request.idempotency_key()] = request.ticket()
      self.next_ticket += 1
      self.pending.push(request)
      self.metrics.accepted += 1
      self.audit(
        self.next_ticket - 1,
        now,
        QueuedCommand,
        QueuedCommand,
        0,
        "command queued",
      )
      Ok(self.pending[self.pending.length() - 1])
    }
  }
}

///|
fn CommandScheduler::find(self : CommandScheduler, ticket : Int) -> Int? {
  for index, request in self.pending {
    if request.ticket() == ticket {
      return Some(index)
    }
  }
  None
}

///|
pub fn CommandScheduler::get(
  self : CommandScheduler,
  ticket : Int,
) -> CommandRequest? {
  match self.find(ticket) {
    None => None
    Some(index) => Some(self.pending[index])
  }
}

///|
pub fn CommandScheduler::dispatch(
  self : CommandScheduler,
  policy : CommandPolicy,
  now : Int,
) -> Result[CommandDispatch?, Diagnostic] {
  let available : Array[CommandRequest] = []
  for request in self.pending {
    if request.lifecycle() == QueuedCommand && request.next_attempt_at() <= now {
      available.push(request)
    }
  }
  if available.length() == 0 {
    return Ok(None)
  }
  available.sort_by(scheduler_candidate)
  let selected = available[0]
  match self.find(selected.ticket()) {
    None =>
      Err(Diagnostic::new(StateViolation, "scheduler candidate disappeared"))
    Some(index) =>
      if now > selected.deadline() {
        let request = self.pending[index]
        request.lifecycle = ExpiredCommand
        self.pending[index] = request
        self.metrics.expired += 1
        self.audit(
          selected.ticket(),
          now,
          QueuedCommand,
          ExpiredCommand,
          selected.attempts(),
          "command deadline expired",
        )
        Ok(None)
      } else {
        match evaluate_command(policy, selected.object()) {
          { accepted: false, .. } => {
            let request = self.pending[index]
            request.lifecycle = RejectedCommand
            request.last_error = "command policy rejected request"
            self.pending[index] = request
            self.metrics.rejected += 1
            self.audit(
              selected.ticket(),
              now,
              QueuedCommand,
              RejectedCommand,
              selected.attempts(),
              request.last_error,
            )
            Err(
              Diagnostic::new(
                InvalidQualifier,
                "command policy rejected request",
              ),
            )
          }
          { accepted: true, .. } => {
            let request = self.pending[index]
            request.attempts += 1
            request.lifecycle = DispatchedCommand
            self.pending[index] = request
            self.metrics.dispatched += 1
            self.audit(
              selected.ticket(),
              now,
              QueuedCommand,
              DispatchedCommand,
              request.attempts(),
              "command dispatched",
            )
            Ok(
              Some({
                ticket: request.ticket(),
                station: request.station(),
                object: request.object(),
                attempt: request.attempts(),
                expires_at: now + request.policy().timeout(),
              }),
            )
          }
        }
      }
  }
}

///|
pub fn CommandScheduler::confirm(
  self : CommandScheduler,
  ticket : Int,
  now : Int,
  accepted : Bool,
  message? : String = "",
) -> Result[CommandRequest, Diagnostic] {
  match self.find(ticket) {
    None => Err(Diagnostic::new(InvalidQualifier, "unknown command ticket"))
    Some(index) => {
      let request = self.pending[index]
      if request.lifecycle() != DispatchedCommand &&
        request.lifecycle() != AwaitingConfirmation {
        Err(
          Diagnostic::new(
            StateViolation,
            "command is not awaiting confirmation",
          ),
        )
      } else if accepted {
        request.lifecycle = CompletedCommand
        request.last_error = message
        self.pending[index] = request
        self.metrics.completed += 1
        self.audit(
          ticket,
          now,
          DispatchedCommand,
          CompletedCommand,
          request.attempts(),
          message,
        )
        Ok(request)
      } else if request.attempts() < request.policy().max_attempts() &&
        now < request.deadline() {
        request.lifecycle = QueuedCommand
        request.next_attempt_at = now +
          request.policy().backoff() * request.attempts()
        request.last_error = message
        self.pending[index] = request
        self.metrics.failed += 1
        self.metrics.retried += 1
        self.audit(
          ticket,
          now,
          DispatchedCommand,
          QueuedCommand,
          request.attempts(),
          "command scheduled for retry",
        )
        Ok(request)
      } else {
        request.lifecycle = FailedCommand
        request.last_error = message
        self.pending[index] = request
        self.metrics.failed += 1
        self.audit(
          ticket,
          now,
          DispatchedCommand,
          FailedCommand,
          request.attempts(),
          message,
        )
        Ok(request)
      }
    }
  }
}

///|
pub fn CommandScheduler::cancel(
  self : CommandScheduler,
  ticket : Int,
  now : Int,
  reason? : String = "cancelled by operator",
) -> Result[CommandRequest, Diagnostic] {
  match self.find(ticket) {
    None => Err(Diagnostic::new(InvalidQualifier, "unknown command ticket"))
    Some(index) => {
      let request = self.pending[index]
      if request.lifecycle() == CompletedCommand ||
        request.lifecycle() == FailedCommand ||
        request.lifecycle() == ExpiredCommand {
        Err(
          Diagnostic::new(
            StateViolation,
            "terminal command cannot be cancelled",
          ),
        )
      } else {
        request.lifecycle = CancelledCommand
        request.last_error = reason
        self.pending[index] = request
        self.metrics.cancelled += 1
        self.audit(
          ticket,
          now,
          request.lifecycle(),
          CancelledCommand,
          request.attempts(),
          reason,
        )
        Ok(request)
      }
    }
  }
}

///|
pub fn CommandScheduler::expire(
  self : CommandScheduler,
  now : Int,
) -> Array[CommandRequest] {
  let expired : Array[CommandRequest] = []
  for index, request in self.pending {
    if (
        request.lifecycle() == QueuedCommand ||
        request.lifecycle() == DispatchedCommand
      ) &&
      now > request.deadline() {
      let updated = self.pending[index]
      updated.lifecycle = ExpiredCommand
      updated.last_error = "command deadline expired"
      self.pending[index] = updated
      self.metrics.expired += 1
      self.audit(
        request.ticket(),
        now,
        request.lifecycle(),
        ExpiredCommand,
        request.attempts(),
        updated.last_error,
      )
      expired.push(updated)
    }
  }
  expired
}

///|
pub fn CommandScheduler::terminal(
  self : CommandScheduler,
) -> Array[CommandRequest] {
  let result : Array[CommandRequest] = []
  for request in self.pending {
    match request.lifecycle() {
      CompletedCommand
      | FailedCommand
      | RejectedCommand
      | ExpiredCommand
      | CancelledCommand => result.push(request)
      _ => ()
    }
  }
  result.sort_by((left, right) => left.ticket() - right.ticket())
  result
}

///|
pub fn command_priority_examples() -> Array[CommandPriority] {
  [EmergencyPriority, HighPriority, NormalPriority, LowPriority]
}

///|
pub fn command_lifecycle_examples() -> Array[CommandLifecycle] {
  [
    QueuedCommand,
    DispatchedCommand,
    AwaitingConfirmation,
    CompletedCommand,
    FailedCommand,
    RejectedCommand,
    ExpiredCommand,
    CancelledCommand,
  ]
}
