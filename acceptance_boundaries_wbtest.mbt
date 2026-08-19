///|
test "boundary addresses and common addresses" {
  assert_true(InformationAddress::new(0) is Ok(_))
  assert_true(InformationAddress::new(0xffffff) is Ok(_))
  assert_true(InformationAddress::new(-1) is Err(_))
  assert_true(InformationAddress::new(0x1000000) is Err(_))
  assert_true(CommonAddress::new(0) is Ok(_))
  assert_true(CommonAddress::new(0xffff) is Ok(_))
  assert_true(CommonAddress::new(-1) is Err(_))
  assert_true(CommonAddress::new(0x10000) is Err(_))
}

///|
test "cause and connection parameter boundaries" {
  assert_true(
    CauseOfTransmission::new(Spontaneous, originator=0, qualifier=0) is Ok(_),
  )
  assert_true(
    CauseOfTransmission::new(Spontaneous, originator=255, qualifier=63) is Ok(_),
  )
  assert_true(CauseOfTransmission::new(Spontaneous, originator=256) is Err(_))
  assert_true(CauseOfTransmission::new(Spontaneous, qualifier=64) is Err(_))
  assert_true(ConnectionParameters::new(1, 1, 3, 2, 1, 1) is Ok(_))
  assert_true(ConnectionParameters::new(0, 1, 3, 2, 1, 1) is Err(_))
  assert_true(ConnectionParameters::new(2, 3, 3, 2, 1, 1) is Err(_))
  assert_true(ConnectionParameters::new(2, 1, 1, 2, 1, 1) is Err(_))
}

///|
test "CP24 and CP56 edge values" {
  let short = Cp24Time::new(59999, 59).unwrap()
  assert_eq(short.to_array().length(), 3)
  assert_true(Cp24Time::new(60000, 0) is Err(_))
  let long = Cp56Time::new(24, 2, 29, 23, 59, 59999, weekday=7).unwrap()
  assert_eq(long.to_array().length(), 7)
  assert_true(Cp56Time::new(23, 2, 29, 0, 0, 0) is Err(_))
  assert_true(Cp56Time::new(24, 2, 30, 0, 0, 0) is Err(_))
  match Cp56Time::from_bytes(Bytes::from_array(long.to_array())) {
    Ok(decoded) => assert_eq(decoded, long)
    Err(_) => fail("CP56 round trip failed")
  }
}

///|
test "quality descriptor flag matrix" {
  for raw in [0, 1, 0x10, 0x20, 0x40, 0x80, 0xf1, 0xff] {
    let descriptor = QualityDescriptor::from_byte(raw).unwrap()
    assert_eq(descriptor.to_byte(), raw & 0xf1)
  }
  assert_true(QualityDescriptor::from_byte(-1) is Err(_))
  assert_true(QualityDescriptor::from_byte(256) is Err(_))
  assert_true(!QualityDescriptor::clear().with_invalid(true).is_usable())
}

///|
test "signed measurement boundaries" {
  assert_true(NormalizedValue::new(-32768) is Ok(_))
  assert_true(NormalizedValue::new(32767) is Ok(_))
  assert_true(NormalizedValue::new(-32769) is Err(_))
  assert_true(ScaledValue::new(32768) is Err(_))
  assert_eq(decode_signed16(0, 128).unwrap(), -32768)
  assert_eq(decode_signed16(255, 127).unwrap(), 32767)
  assert_eq(encode_signed16(-1).unwrap()[0].to_int(), 255)
}

///|
test "application object construction and time precision" {
  assert_eq(MSpTa.number(), 2)
  assert_eq(MSpTb.number(), 30)
  assert_eq(application_type(2), MSpTa)
  assert_eq(application_type(30), MSpTb)
  assert_eq(time_tag_kind_for_type(MSpTa), Cp24TimeTag)
  assert_eq(time_tag_kind_for_type(MSpTb), Cp56TimeTag)
  let address = InformationAddress::new(100).unwrap()
  let short_tag = TimeTag::Short(Cp24Time::new(1000, 1).unwrap())
  let long_tag = TimeTag::Long(Cp56Time::new(26, 1, 1, 1, 1, 1000).unwrap())
  assert_true(single_point_object(address, true) is Ok(_))
  assert_true(single_point_object(address, true, time_tag=short_tag) is Ok(_))
  assert_true(single_point_object(address, true, time_tag=long_tag) is Ok(_))
  assert_true(
    ApplicationObject::new(address, SingleCommand(true, 1), time_tag=short_tag)
    is Err(_),
  )
}

///|
test "extended ASDU round trips address and quality" {
  let address = InformationAddress::new(0x10203).unwrap()
  let common = CommonAddress::new(2).unwrap()
  let cause = CauseOfTransmission::new(Spontaneous).unwrap()
  let object = normalized_object(
    address,
    -1234,
    quality=QualityDescriptor::clear().with_substituted(true),
  ).unwrap()
  let envelope = AsduEnvelope::new(MMeNa, false, cause, common, [object]).unwrap()
  let encoded = encode_extended_asdu(envelope).unwrap()
  match decode_extended_asdu(encoded) {
    Ok(decoded) => {
      assert_eq(decoded.count(), 1)
      assert_eq(decoded.objects()[0].address(), address)
      assert_eq(decoded.objects()[0].type_id(), MMeNa)
    }
    Err(error) => fail(error.to_line())
  }
}

///|
test "extended ASDU rejects truncation and trailing bytes" {
  let address = InformationAddress::new(1).unwrap()
  let cause = CauseOfTransmission::new(Spontaneous).unwrap()
  let common = CommonAddress::new(1).unwrap()
  let object = single_point_object(address, true).unwrap()
  let envelope = AsduEnvelope::new(MSpNa, false, cause, common, [object]).unwrap()
  let encoded = encode_extended_asdu(envelope).unwrap()
  assert_true(
    decode_extended_asdu(encoded[:encoded.length() - 1].to_owned()) is Err(_),
  )
  let extra = encoded.to_array()
  extra.push(0)
  assert_true(decode_extended_asdu(Bytes::from_array(extra)) is Err(_))
  assert_true(decode_extended_asdu(b"\x01\x00\x00\x00\x01\x00") is Err(_))
}

///|
test "sequence ring and window wraparound" {
  assert_eq(sequence_normalize(-1), 32767)
  assert_eq(sequence_next(32767), 0)
  assert_eq(sequence_previous(0), 32767)
  assert_eq(sequence_distance(32767, 0), 1)
  let window = SequenceWindow::new(2).unwrap()
  assert_true(window.reserve_send() is Ok(_))
  assert_true(window.reserve_send() is Ok(_))
  assert_true(window.reserve_send() is Err(_))
  assert_eq(window.acknowledge(1).unwrap(), 1)
  assert_eq(window.available(), 1)
}

///|
test "stream decoder partial and multi-frame input" {
  let first = encode_frame(supervisory_frame(0))
  let second = encode_frame(unnumbered_frame(UCommand::control(TestFrame)))
  let bytes = first.to_array()
  for byte in second {
    bytes.push(byte)
  }
  let decoder = ApduStreamDecoder::new().unwrap()
  ignore(decoder.push(Bytes::from_array(bytes[:3].to_owned())).unwrap())
  assert_true(decoder.next() is NeedMore(_))
  ignore(decoder.push(Bytes::from_array(bytes[3:].to_owned())).unwrap())
  assert_eq(decoder.available_frames(), 2)
  assert_true(decoder.next() is Complete(_, _))
  assert_true(decoder.next() is Complete(_, _))
}

///|
test "point store revisions and bounded history" {
  let store = PointStore::new(CommonAddress::new(1).unwrap(), history_limit=2).unwrap()
  let address = InformationAddress::new(1).unwrap()
  let first = single_point_object(address, true).unwrap()
  let second = single_point_object(address, false).unwrap()
  assert_true(store.upsert(first, 1) is Ok(_))
  assert_true(store.upsert(second, 2) is Ok(_))
  assert_eq(store.get(address).unwrap().revision(), 2)
  assert_eq(store.history_len(), 2)
  assert_true(store.remove(address, 3) is Ok(_))
  assert_eq(store.len(), 0)
  assert_eq(store.history_len(), 2)
}

///|
test "store filters and transaction rollback" {
  let store = PointStore::new(CommonAddress::new(1).unwrap()).unwrap()
  let monitor_address = InformationAddress::new(1).unwrap()
  let control_address = InformationAddress::new(2).unwrap()
  ignore(
    store
    .upsert(single_point_object(monitor_address, true).unwrap(), 1)
    .unwrap(),
  )
  ignore(
    store
    .upsert(single_command_object(control_address, true, 1).unwrap(), 1)
    .unwrap(),
  )
  assert_eq(store.query(PointFilter::monitoring()).length(), 1)
  assert_eq(store.query(PointFilter::control()).length(), 1)
  let transaction = StoreTransaction::new()
  ignore(
    transaction
    .stage(
      single_point_object(InformationAddress::new(3).unwrap(), false).unwrap(),
      2,
    )
    .unwrap(),
  )
  assert_eq(transaction.pending_count(), 1)
  transaction.rollback()
  assert_eq(transaction.pending_count(), 0)
}

///|
test "service plan batches and command policy" {
  let request = InterrogationRequest::new(1, qualifier=20)
  let address = InformationAddress::new(1).unwrap()
  let objects = [
    single_point_object(address, true).unwrap(),
    single_point_object(InformationAddress::new(2).unwrap(), false).unwrap(),
  ]
  let plan = InterrogationPlan::new(request, objects, batch_size=1).unwrap()
  assert_true(plan.activate() is Ok(_))
  assert_eq(plan.next_batch().unwrap().length(), 1)
  assert_eq(plan.next_batch().unwrap().length(), 1)
  let policy = CommandPolicy::deny_all()
  let command = single_command_object(address, true, 1).unwrap()
  assert_true(!evaluate_command(policy, command).accepted())
  policy.allow(address)
  assert_true(evaluate_command(policy, command).accepted())
}

///|
test "hex, cursor, crc and limits" {
  let data = hex_decode("680401000000").unwrap()
  assert_eq(hex_encode(data), "680401000000")
  assert_eq(crc16_ibm(data), 0xcff8U)
  let cursor = ByteCursor::new(data)
  assert_eq(cursor.read_byte().unwrap(), b'\x68')
  assert_eq(cursor.read_byte().unwrap(), b'\x04')
  assert_eq(cursor.read_u32().unwrap(), 1U)
  assert_true(cursor.done())
  assert_true(hex_decode("0") is Err(_))
  assert_true(ResourceLimits::new(5, 1, 1, 1, 1, 1) is Err(_))
}

///|
test "deterministic benchmark workload" {
  let result = run_benchmark_workload(16, 8).unwrap()
  assert_eq(result.encoded_frames(), 16)
  assert_eq(result.encoded_bytes(), 16 * (6 + 8))
  let suite = default_benchmark_suite()
  assert_eq(suite.len(), 3)
  assert_eq(result.checksum(), benchmark_fixture_checksums()[0])
}

///|
test "health and profile negotiation" {
  let session = Session::new()
  let report = assess_session(session.snapshot())
  assert_true(report.score() < 100)
  let profiles = profile_examples()
  assert_eq(profiles.length(), 1)
  assert_true(negotiate_profiles(profiles[0], profiles[0]) is CompatibleProfile)
}
