///|
/// Application service classes supported by the portable core.
pub enum ServiceKind {
  InterrogationService
  CounterInterrogationService
  ReadService
  ClockSyncService
  CommandService
  ResetService
  DelayAcquisitionService
} derive(Eq, Debug)

///|
pub fn service_kind_examples() -> Array[ServiceKind] {
  [
    InterrogationService,
    CounterInterrogationService,
    ReadService,
    ClockSyncService,
    CommandService,
    ResetService,
    DelayAcquisitionService,
  ]
}

///|
/// Result state used by application transactions.
pub enum ServiceStatus {
  IdleService
  ActiveService
  ConfirmedService
  TerminatedService
  RejectedService
  FailedService
} derive(Eq, Debug)

///|
pub fn service_status_examples() -> Array[ServiceStatus] {
  [
    IdleService,
    ActiveService,
    ConfirmedService,
    TerminatedService,
    RejectedService,
    FailedService,
  ]
}

///|
/// An application service request independent of a transport.
pub struct ServiceRequest {
  service : ServiceKind
  address : InformationAddress
  common_address : CommonAddress
  qualifier : Int
  created_at : Int
  originator : Int
} derive(Eq, Debug)

///|
pub fn ServiceRequest::new(
  service : ServiceKind,
  address : InformationAddress,
  common_address : CommonAddress,
  qualifier : Int,
  created_at : Int,
  originator? : Int = 0,
) -> Result[ServiceRequest, Diagnostic] {
  if qualifier < 0 || qualifier > 255 {
    Err(
      Diagnostic::new(InvalidQualifier, "service qualifier must fit one byte"),
    )
  } else if originator < 0 || originator > 255 {
    Err(Diagnostic::new(InvalidAddress, "service originator must fit one byte"))
  } else {
    Ok({ service, address, common_address, qualifier, created_at, originator })
  }
}

///|
pub fn ServiceRequest::service(self : ServiceRequest) -> ServiceKind {
  self.service
}

///|
pub fn ServiceRequest::address(self : ServiceRequest) -> InformationAddress {
  self.address
}

///|
pub fn ServiceRequest::common_address(self : ServiceRequest) -> CommonAddress {
  self.common_address
}

///|
pub fn ServiceRequest::qualifier(self : ServiceRequest) -> Int {
  self.qualifier
}

///|
pub fn ServiceRequest::created_at(self : ServiceRequest) -> Int {
  self.created_at
}

///|
pub fn ServiceRequest::originator(self : ServiceRequest) -> Int {
  self.originator
}

///|
/// A service response with optional application data.
pub struct ServiceResponse {
  request : ServiceRequest
  status : ServiceStatus
  cause : CauseOfTransmission
  objects : Array[ApplicationObject]
  message : String
} derive(Debug)

///|
pub fn ServiceResponse::new(
  request : ServiceRequest,
  status : ServiceStatus,
  cause : CauseOfTransmission,
  objects : Array[ApplicationObject],
  message? : String = "",
) -> ServiceResponse {
  { request, status, cause, objects, message }
}

///|
pub fn ServiceResponse::request(self : ServiceResponse) -> ServiceRequest {
  self.request
}

///|
pub fn ServiceResponse::status(self : ServiceResponse) -> ServiceStatus {
  self.status
}

///|
pub fn ServiceResponse::cause(self : ServiceResponse) -> CauseOfTransmission {
  self.cause
}

///|
pub fn ServiceResponse::objects(
  self : ServiceResponse,
) -> Array[ApplicationObject] {
  self.objects.copy()
}

///|
pub fn ServiceResponse::message(self : ServiceResponse) -> String {
  self.message
}

///|
/// A total interrogation plan which can be emitted in deterministic batches.
pub struct InterrogationPlan {
  request : InterrogationRequest
  objects : Array[ApplicationObject]
  batch_size : Int
  mut cursor : Int
  mut status : ServiceStatus
} derive(Debug)

///|
pub fn InterrogationPlan::new(
  request : InterrogationRequest,
  objects : Array[ApplicationObject],
  batch_size? : Int = 16,
) -> Result[InterrogationPlan, String] {
  if batch_size < 1 || batch_size > 127 {
    Err("interrogation batch size must be between 1 and 127")
  } else {
    Ok({ request, objects, batch_size, cursor: 0, status: IdleService })
  }
}

///|
pub fn InterrogationPlan::status(self : InterrogationPlan) -> ServiceStatus {
  self.status
}

///|
pub fn InterrogationPlan::remaining(self : InterrogationPlan) -> Int {
  self.objects.length() - self.cursor
}

///|
pub fn InterrogationPlan::activate(
  self : InterrogationPlan,
) -> Result[Int, String] {
  if self.status != IdleService {
    Err("interrogation plan is not idle")
  } else {
    self.status = ActiveService
    Ok(Cause::Activation.number())
  }
}

///|
pub fn InterrogationPlan::next_batch(
  self : InterrogationPlan,
) -> Result[Array[ApplicationObject], String] {
  if self.status != ActiveService {
    Err("interrogation plan is not active")
  } else if self.cursor >= self.objects.length() {
    self.status = TerminatedService
    Ok([])
  } else {
    let end = if self.cursor + self.batch_size > self.objects.length() {
      self.objects.length()
    } else {
      self.cursor + self.batch_size
    }
    let result = self.objects[self.cursor:end].to_owned()
    self.cursor = end
    if self.cursor >= self.objects.length() {
      self.status = ConfirmedService
    }
    Ok(result)
  }
}

///|
pub fn InterrogationPlan::terminate(
  self : InterrogationPlan,
) -> Result[Int, String] {
  if self.status != ActiveService && self.status != ConfirmedService {
    Err("interrogation plan is not terminable")
  } else {
    self.status = TerminatedService
    Ok(Cause::ActivationTermination.number())
  }
}

///|
pub fn InterrogationPlan::request(
  self : InterrogationPlan,
) -> InterrogationRequest {
  self.request
}

///|
/// Build plans from a point store while retaining type and address boundaries.
pub fn create_interrogation_plan(
  store : PointStore,
  request : InterrogationRequest,
  filter : PointFilter,
  batch_size? : Int = 16,
) -> Result[InterrogationPlan, String] {
  InterrogationPlan::new(request, store.objects(filter), batch_size~)
}

///|
/// Counter-interrogation request used for historical counter snapshots.
pub struct CounterInterrogationRequest {
  common_address : CommonAddress
  qualifier : Int
  created_at : Int
} derive(Eq, Debug)

///|
pub fn CounterInterrogationRequest::new(
  common_address : CommonAddress,
  qualifier : Int,
  created_at : Int,
) -> Result[CounterInterrogationRequest, String] {
  if qualifier < 0 || qualifier > 255 {
    Err("counter interrogation qualifier must fit one byte")
  } else {
    Ok({ common_address, qualifier, created_at })
  }
}

///|
pub fn CounterInterrogationRequest::common_address(
  self : CounterInterrogationRequest,
) -> CommonAddress {
  self.common_address
}

///|
pub fn CounterInterrogationRequest::qualifier(
  self : CounterInterrogationRequest,
) -> Int {
  self.qualifier
}

///|
pub fn CounterInterrogationRequest::created_at(
  self : CounterInterrogationRequest,
) -> Int {
  self.created_at
}

///|
/// Read service state for a single information object.
pub struct ReadTransaction {
  request : ServiceRequest
  mut status : ServiceStatus
} derive(Debug)

///|
pub fn ReadTransaction::new(
  request : ServiceRequest,
) -> Result[ReadTransaction, String] {
  if request.service() != ReadService {
    Err("read transaction requires a read service request")
  } else {
    Ok({ request, status: IdleService })
  }
}

///|
pub fn ReadTransaction::activate(
  self : ReadTransaction,
) -> Result[Unit, String] {
  if self.status != IdleService {
    Err("read transaction is not idle")
  } else {
    self.status = ActiveService
    Ok(())
  }
}

///|
pub fn ReadTransaction::complete(
  self : ReadTransaction,
  object : ApplicationObject,
) -> Result[ServiceResponse, String] {
  if self.status != ActiveService {
    Err("read transaction is not active")
  } else if object.address() != self.request.address() {
    Err("read response address does not match request")
  } else {
    self.status = TerminatedService
    let cause = CauseOfTransmission::from_number(7).unwrap()
    Ok(ServiceResponse::new(self.request, ConfirmedService, cause, [object]))
  }
}

///|
pub fn ReadTransaction::reject(
  self : ReadTransaction,
  message : String,
) -> ServiceResponse {
  self.status = RejectedService
  ServiceResponse::new(
    self.request,
    RejectedService,
    CauseOfTransmission::from_number(7, positive=false).unwrap(),
    [],
    message~,
  )
}

///|
pub fn ReadTransaction::status(self : ReadTransaction) -> ServiceStatus {
  self.status
}

///|
/// Clock synchronization service with a deterministic skew calculation.
pub struct ClockSyncTransaction {
  request : ServiceRequest
  mut status : ServiceStatus
  mut received : Cp56Time?
  mut applied_at : Int?
} derive(Debug)

///|
pub fn ClockSyncTransaction::new(
  request : ServiceRequest,
) -> Result[ClockSyncTransaction, String] {
  if request.service() != ClockSyncService {
    Err("clock transaction requires a clock service request")
  } else {
    Ok({ request, status: IdleService, received: None, applied_at: None })
  }
}

///|
pub fn ClockSyncTransaction::activate(
  self : ClockSyncTransaction,
) -> Result[Unit, String] {
  if self.status != IdleService {
    Err("clock transaction is not idle")
  } else {
    self.status = ActiveService
    Ok(())
  }
}

///|
pub fn ClockSyncTransaction::apply(
  self : ClockSyncTransaction,
  timestamp : Cp56Time,
  applied_at : Int,
) -> Result[Int, String] {
  if self.status != ActiveService {
    Err("clock transaction is not active")
  } else {
    self.received = Some(timestamp)
    self.applied_at = Some(applied_at)
    self.status = ConfirmedService
    Ok(applied_at - timestamp.ordering_key())
  }
}

///|
pub fn ClockSyncTransaction::status(
  self : ClockSyncTransaction,
) -> ServiceStatus {
  self.status
}

///|
pub fn ClockSyncTransaction::received(self : ClockSyncTransaction) -> Cp56Time? {
  self.received
}

///|
/// A command authorization policy for host applications.
pub struct CommandPolicy {
  allowed : Map[Int, Bool]
  allow_all : Bool
  mut max_qualifier : Int
} derive(Debug)

///|
pub fn CommandPolicy::deny_all() -> CommandPolicy {
  { allowed: {}, allow_all: false, max_qualifier: 255 }
}

///|
pub fn CommandPolicy::allow_all() -> CommandPolicy {
  { allowed: {}, allow_all: true, max_qualifier: 255 }
}

///|
pub fn CommandPolicy::allow(
  self : CommandPolicy,
  address : InformationAddress,
) -> Unit {
  self.allowed[address.number()] = true
}

///|
pub fn CommandPolicy::deny(
  self : CommandPolicy,
  address : InformationAddress,
) -> Unit {
  self.allowed[address.number()] = false
}

///|
pub fn CommandPolicy::set_max_qualifier(
  self : CommandPolicy,
  value : Int,
) -> Result[Unit, String] {
  if value < 0 || value > 255 {
    Err("command qualifier limit must fit one byte")
  } else {
    self.max_qualifier = value
    Ok(())
  }
}

///|
pub fn CommandPolicy::permits(
  self : CommandPolicy,
  object : ApplicationObject,
) -> Bool {
  let address_allowed = if self.allow_all {
    true
  } else {
    match self.allowed.get(object.address().number()) {
      Some(value) => value
      None => false
    }
  }
  address_allowed && object.is_command()
}

///|
pub struct CommandOutcome {
  accepted : Bool
  status : ServiceStatus
  object : ApplicationObject?
  message : String
} derive(Debug)

///|
pub fn CommandOutcome::accepted(self : CommandOutcome) -> Bool {
  self.accepted
}

///|
pub fn CommandOutcome::status(self : CommandOutcome) -> ServiceStatus {
  self.status
}

///|
pub fn CommandOutcome::object(self : CommandOutcome) -> ApplicationObject? {
  self.object
}

///|
pub fn CommandOutcome::message(self : CommandOutcome) -> String {
  self.message
}

///|
pub fn evaluate_command(
  policy : CommandPolicy,
  object : ApplicationObject,
) -> CommandOutcome {
  if !object.is_command() {
    {
      accepted: false,
      status: RejectedService,
      object: None,
      message: "object is not a command",
    }
  } else if !policy.permits(object) {
    {
      accepted: false,
      status: RejectedService,
      object: None,
      message: "command is denied by policy",
    }
  } else {
    {
      accepted: true,
      status: ConfirmedService,
      object: Some(object),
      message: "command accepted",
    }
  }
}

///|
/// A FIFO command queue with explicit outcomes.
pub struct CommandQueue {
  pending : Array[ApplicationObject]
  completed : Array[CommandOutcome]
  limit : Int
} derive(Debug)

///|
pub fn CommandQueue::new(limit? : Int = 256) -> Result[CommandQueue, String] {
  if limit < 1 || limit > 65535 {
    Err("command queue limit is outside the supported range")
  } else {
    Ok({ pending: [], completed: [], limit })
  }
}

///|
pub fn CommandQueue::pending_count(self : CommandQueue) -> Int {
  self.pending.length()
}

///|
pub fn CommandQueue::completed_count(self : CommandQueue) -> Int {
  self.completed.length()
}

///|
pub fn CommandQueue::enqueue(
  self : CommandQueue,
  object : ApplicationObject,
) -> Result[Unit, String] {
  if !object.is_command() {
    Err("only control direction objects can enter the command queue")
  } else if self.pending.length() >= self.limit {
    Err("command queue is full")
  } else {
    self.pending.push(object)
    Ok(())
  }
}

///|
pub fn CommandQueue::process_one(
  self : CommandQueue,
  policy : CommandPolicy,
) -> CommandOutcome? {
  match self.pending.pop() {
    None => None
    Some(object) => {
      let outcome = evaluate_command(policy, object)
      self.completed.push(outcome)
      Some(outcome)
    }
  }
}

///|
pub fn CommandQueue::outcomes(self : CommandQueue) -> Array[CommandOutcome] {
  self.completed.copy()
}

///|
pub fn application_service_examples() -> Array[ServiceStatus] {
  [IdleService, ActiveService, ConfirmedService, TerminatedService]
}
