///|
test "information frame round trip" {
  let frame = information_frame(17, 9, b"hello")
  let encoded = encode_frame(frame)
  inspect(encoded.length(), content="11")
  match decode_frame(encoded) {
    Ok(decoded) => {
      debug_inspect(decoded.kind, content="Information")
      inspect(decoded.send_sequence, content="17")
      inspect(decoded.receive_sequence, content="9")
      inspect(decoded.payload, content="b\"hello\"")
    }
    Err(message) => fail(message)
  }
}

///|
test "supervisory and unnumbered controls" {
  let s = decode_frame(encode_frame(supervisory_frame(22)))
  let u = decode_frame(
    encode_frame(unnumbered_frame(UCommand::control(UCommand::TestFrame))),
  )
  match s {
    Ok(frame) => inspect(frame.receive_sequence, content="22")
    Err(message) => fail(message)
  }
  match u {
    Ok(frame) => debug_inspect(u_command(frame.control), content="TestFrame")
    Err(message) => fail(message)
  }
}

///|
test "ASDU normalized value" {
  let header : AsduHeader = {
    type_id: TypeId::NormalizedValue,
    variable_count: 1,
    sequence: false,
    cause: 3,
    common_address: 2,
  }
  let encoded = encode_asdu(header, [InformationObject::Normalized(1234, 0)])
  match decode_asdu(encoded) {
    Ok((decoded_header, objects)) => {
      inspect(decoded_header.cause, content="3")
      debug_inspect(objects[0], content="Normalized(1234, 0)")
    }
    Err(message) => fail(message)
  }
}

///|
test "session enforces start and receive windows" {
  let session = Session::new(window_size=2)
  match session.send(b"x") {
    Ok(_) => fail("send must require STARTDT")
    Err(message) => inspect(message, content="data transfer is not started")
  }
  let session = Session::new(window_size=2)
  let start = session.start()
  let _ = session.receive(start)
  let sent = session.send(b"x")
  match sent {
    Ok(frame) => inspect(frame.send_sequence, content="0")
    Err(message) => fail(message)
  }
}

///|
test "interrogation transaction" {
  let transaction = Interrogation::new(InterrogationRequest::new(1))
  inspect(transaction.activate(), content="6")
  let _ = transaction.record(3)
  inspect(transaction.objects_sent, content="3")
  inspect(transaction.finish(), content="10")
}

///|
test "outstation snapshots" {
  let station = Outstation::new(1)
  station.set_single(100, true)
  station.set_normalized(200, 2300)
  inspect(station.snapshot_single().length(), content="1")
  inspect(station.snapshot_normalized().length(), content="1")
}

///|
test "frame validation and event log" {
  let valid = information_frame(0, 0, b"payload")
  let invalid = information_frame(0, 0, b"")
  debug_inspect(validate_frame(valid), content="Ok(())")
  debug_inspect(
    validate_frame(invalid),
    content="Err(\"I frame payload must not be empty\")",
  )
  let log = EventLog::new()
  log.push(Connected)
  log.push(Sent(0))
  inspect(log.len(), content="2")
}
