///|
/// Machine-readable description of an IEC 104 application type.
pub struct TypeDescriptor {
  type_id : ApplicationType
  name : String
  direction : PointDirection
  time_tag : TimeTagKind
  value_width : Int
  supported : Bool
  command : Bool
} derive(Eq, Debug)

///|
fn descriptor(
  type_id : ApplicationType,
  name : String,
  direction : PointDirection,
  time_tag : TimeTagKind,
  value_width : Int,
  supported : Bool,
  command : Bool,
) -> TypeDescriptor {
  { type_id, name, direction, time_tag, value_width, supported, command }
}

///|
pub fn TypeDescriptor::type_id(self : TypeDescriptor) -> ApplicationType {
  self.type_id
}

///|
pub fn TypeDescriptor::name(self : TypeDescriptor) -> String {
  self.name
}

///|
pub fn TypeDescriptor::direction(self : TypeDescriptor) -> PointDirection {
  self.direction
}

///|
pub fn TypeDescriptor::time_tag(self : TypeDescriptor) -> TimeTagKind {
  self.time_tag
}

///|
pub fn TypeDescriptor::value_width(self : TypeDescriptor) -> Int {
  self.value_width
}

///|
pub fn TypeDescriptor::supported(self : TypeDescriptor) -> Bool {
  self.supported
}

///|
pub fn TypeDescriptor::is_command(self : TypeDescriptor) -> Bool {
  self.command
}

///|
/// Return the standard catalog used to negotiate object capabilities.
pub fn application_type_catalog() -> Array[TypeDescriptor] {
  [
    descriptor(MSpNa, "M_SP_NA_1", MonitorDirection, NoTimeTag, 1, true, false),
    descriptor(MDpNa, "M_DP_NA_1", MonitorDirection, NoTimeTag, 1, true, false),
    descriptor(MStNa, "M_ST_NA_1", MonitorDirection, NoTimeTag, 2, true, false),
    descriptor(MBoNa, "M_BO_NA_1", MonitorDirection, NoTimeTag, 5, true, false),
    descriptor(MMeNa, "M_ME_NA_1", MonitorDirection, NoTimeTag, 3, true, false),
    descriptor(MMeNb, "M_ME_NB_1", MonitorDirection, NoTimeTag, 3, true, false),
    descriptor(MMeNc, "M_ME_NC_1", MonitorDirection, NoTimeTag, 5, true, false),
    descriptor(MItNa, "M_IT_NA_1", MonitorDirection, NoTimeTag, 5, true, false),
    descriptor(
      MSpTa,
      "M_SP_TA_1",
      MonitorDirection,
      Cp24TimeTag,
      1,
      true,
      false,
    ),
    descriptor(
      MDpTa,
      "M_DP_TA_1",
      MonitorDirection,
      Cp24TimeTag,
      1,
      true,
      false,
    ),
    descriptor(
      MStTa,
      "M_ST_TA_1",
      MonitorDirection,
      Cp24TimeTag,
      2,
      true,
      false,
    ),
    descriptor(
      MBoTa,
      "M_BO_TA_1",
      MonitorDirection,
      Cp24TimeTag,
      5,
      true,
      false,
    ),
    descriptor(
      MMeTa,
      "M_ME_TA_1",
      MonitorDirection,
      Cp24TimeTag,
      3,
      true,
      false,
    ),
    descriptor(
      MMeTb,
      "M_ME_TB_1",
      MonitorDirection,
      Cp24TimeTag,
      3,
      true,
      false,
    ),
    descriptor(
      MMeTc,
      "M_ME_TC_1",
      MonitorDirection,
      Cp24TimeTag,
      5,
      true,
      false,
    ),
    descriptor(
      MItTa,
      "M_IT_TA_1",
      MonitorDirection,
      Cp24TimeTag,
      5,
      true,
      false,
    ),
    descriptor(
      MEpTa,
      "M_EP_TA_1",
      MonitorDirection,
      Cp24TimeTag,
      4,
      false,
      false,
    ),
    descriptor(
      MEpTb,
      "M_EP_TB_1",
      MonitorDirection,
      Cp56TimeTag,
      4,
      false,
      false,
    ),
    descriptor(
      MEpTc,
      "M_EP_TC_1",
      MonitorDirection,
      Cp56TimeTag,
      4,
      false,
      false,
    ),
    descriptor(MPsNa, "M_PS_NA_1", MonitorDirection, NoTimeTag, 5, true, false),
    descriptor(MMeNd, "M_ME_ND_1", MonitorDirection, NoTimeTag, 2, true, false),
    descriptor(
      MSpTb,
      "M_SP_TB_1",
      MonitorDirection,
      Cp56TimeTag,
      1,
      true,
      false,
    ),
    descriptor(
      MDpTb,
      "M_DP_TB_1",
      MonitorDirection,
      Cp56TimeTag,
      1,
      true,
      false,
    ),
    descriptor(
      MStTb,
      "M_ST_TB_1",
      MonitorDirection,
      Cp56TimeTag,
      2,
      true,
      false,
    ),
    descriptor(
      MBoTb,
      "M_BO_TB_1",
      MonitorDirection,
      Cp56TimeTag,
      5,
      true,
      false,
    ),
    descriptor(
      MMeTd,
      "M_ME_TD_1",
      MonitorDirection,
      Cp56TimeTag,
      3,
      true,
      false,
    ),
    descriptor(
      MMeTe,
      "M_ME_TE_1",
      MonitorDirection,
      Cp56TimeTag,
      3,
      true,
      false,
    ),
    descriptor(
      MMeTf,
      "M_ME_TF_1",
      MonitorDirection,
      Cp56TimeTag,
      5,
      true,
      false,
    ),
    descriptor(
      MItTb,
      "M_IT_TB_1",
      MonitorDirection,
      Cp56TimeTag,
      5,
      true,
      false,
    ),
    descriptor(
      MEpTd,
      "M_EP_TD_1",
      MonitorDirection,
      Cp56TimeTag,
      4,
      false,
      false,
    ),
    descriptor(
      MEpTe,
      "M_EP_TE_1",
      MonitorDirection,
      Cp56TimeTag,
      4,
      false,
      false,
    ),
    descriptor(
      MEpTf,
      "M_EP_TF_1",
      MonitorDirection,
      Cp56TimeTag,
      4,
      false,
      false,
    ),
    descriptor(MEiNa, "M_EI_NA_1", MonitorDirection, NoTimeTag, 1, true, false),
    descriptor(CScNa, "C_SC_NA_1", ControlDirection, NoTimeTag, 1, true, true),
    descriptor(CDcNa, "C_DC_NA_1", ControlDirection, NoTimeTag, 1, true, true),
    descriptor(CRcNa, "C_RC_NA_1", ControlDirection, NoTimeTag, 1, true, true),
    descriptor(CSeNa, "C_SE_NA_1", ControlDirection, NoTimeTag, 3, true, true),
    descriptor(CSeNb, "C_SE_NB_1", ControlDirection, NoTimeTag, 3, true, true),
    descriptor(CSeNc, "C_SE_NC_1", ControlDirection, NoTimeTag, 5, true, true),
    descriptor(CBoNa, "C_BO_NA_1", ControlDirection, NoTimeTag, 4, true, true),
    descriptor(CIcNa, "C_IC_NA_1", ControlDirection, NoTimeTag, 1, true, true),
    descriptor(CCiNa, "C_CI_NA_1", ControlDirection, NoTimeTag, 1, true, true),
    descriptor(CRdNa, "C_RD_NA_1", ControlDirection, NoTimeTag, 0, true, true),
    descriptor(CCsNa, "C_CS_NA_1", ControlDirection, NoTimeTag, 7, true, true),
    descriptor(CTsNa, "C_TS_NA_1", ControlDirection, NoTimeTag, 2, true, true),
    descriptor(CRpNa, "C_RP_NA_1", ControlDirection, NoTimeTag, 1, true, true),
  ]
}

///|
pub fn type_descriptor(type_id : ApplicationType) -> TypeDescriptor {
  for descriptor in application_type_catalog() {
    if descriptor.type_id() == type_id {
      return descriptor
    }
  }
  descriptor(
    type_id,
    "UNKNOWN",
    point_direction(type_id),
    NoTimeTag,
    0,
    false,
    false,
  )
}

///|
pub fn supported_type_catalog() -> Array[TypeDescriptor] {
  let result : Array[TypeDescriptor] = []
  for descriptor in application_type_catalog() {
    if descriptor.supported() {
      result.push(descriptor)
    }
  }
  result
}

///|
pub fn monitoring_type_catalog() -> Array[TypeDescriptor] {
  let result : Array[TypeDescriptor] = []
  for descriptor in supported_type_catalog() {
    if descriptor.direction() == MonitorDirection {
      result.push(descriptor)
    }
  }
  result
}

///|
pub fn control_type_catalog() -> Array[TypeDescriptor] {
  let result : Array[TypeDescriptor] = []
  for descriptor in supported_type_catalog() {
    if descriptor.direction() == ControlDirection {
      result.push(descriptor)
    }
  }
  result
}

///|
pub fn type_name(type_id : ApplicationType) -> String {
  type_descriptor(type_id).name()
}

///|
pub fn type_is_supported(type_id : ApplicationType) -> Bool {
  type_descriptor(type_id).supported()
}

///|
pub fn type_wire_width(type_id : ApplicationType) -> Int {
  type_descriptor(type_id).value_width() +
  3 +
  time_tag_kind_for_type(type_id).width()
}

///|
/// An ASDU consistency report that can be shown in CLI diagnostics.
pub struct ConformanceReport {
  mut valid : Bool
  type_id : ApplicationType
  mut object_count : Int
  expected_width : Int
  mut actual_width : Int
  issues : Array[String]
} derive(Eq, Debug)

///|
pub fn ConformanceReport::new(type_id : ApplicationType) -> ConformanceReport {
  {
    valid: true,
    type_id,
    object_count: 0,
    expected_width: type_wire_width(type_id),
    actual_width: 0,
    issues: [],
  }
}

///|
pub fn ConformanceReport::valid(self : ConformanceReport) -> Bool {
  self.valid
}

///|
pub fn ConformanceReport::type_id(self : ConformanceReport) -> ApplicationType {
  self.type_id
}

///|
pub fn ConformanceReport::object_count(self : ConformanceReport) -> Int {
  self.object_count
}

///|
pub fn ConformanceReport::expected_width(self : ConformanceReport) -> Int {
  self.expected_width
}

///|
pub fn ConformanceReport::actual_width(self : ConformanceReport) -> Int {
  self.actual_width
}

///|
pub fn ConformanceReport::issues(self : ConformanceReport) -> Array[String] {
  self.issues.copy()
}

///|
pub fn ConformanceReport::add_issue(
  self : ConformanceReport,
  message : String,
) -> Unit {
  self.valid = false
  self.issues.push(message)
}

///|
pub fn validate_envelope(envelope : AsduEnvelope) -> ConformanceReport {
  let report = ConformanceReport::new(envelope.type_id())
  report.object_count = envelope.count()
  if !type_is_supported(envelope.type_id()) {
    report.add_issue("application type is outside the supported catalog")
  }
  for object in envelope.objects() {
    if object.type_id() != envelope.type_id() {
      report.add_issue("object type does not match ASDU type")
    }
    if (object.time_tag() is Some(_)) != envelope.type_id().has_time_tag() {
      report.add_issue("object time-tag presence does not match ASDU type")
    }
    report.actual_width += object.address().number() * 0 +
      application_value_width(object.value()) +
      3 +
      object.time_tag().map_or(0, tag => tag.width())
  }
  report
}

///|
/// Validate a VSQ byte and return its count/sequence pair.
pub fn parse_vsq(value : Int) -> Result[(Int, Bool), String] {
  if value < 0 || value > 255 {
    Err("VSQ must fit one byte")
  } else if (value & 0x7f) == 0 {
    Err("VSQ object count must not be zero")
  } else {
    Ok((value & 0x7f, (value & 0x80) != 0))
  }
}

///|
pub fn validate_common_address(
  value : Int,
) -> Result[CommonAddress, Diagnostic] {
  match CommonAddress::new(value) {
    Ok(address) => Ok(address)
    Err(message) => Err(Diagnostic::new(InvalidAddress, message))
  }
}

///|
pub fn validate_information_address(
  value : Int,
) -> Result[InformationAddress, Diagnostic] {
  match InformationAddress::new(value) {
    Ok(address) => Ok(address)
    Err(message) => Err(Diagnostic::new(InvalidAddress, message))
  }
}

///|
pub fn conformance_examples() -> Array[TypeDescriptor] {
  [
    type_descriptor(MSpNa),
    type_descriptor(CScNa),
    type_descriptor(UnknownType(222)),
  ]
}
