import std/[unittest]
import bag

suite "Basic text fields":
  test "tText - min/max length":
    let data = [("name", "ab")]
    withBag data:
      name: tText"name.error":
        min: 3 or "name.too.short"
        max: 10 or "name.too.long"
    do:
      check inputBag.isInvalid
      check inputBag.getErrors[0][1] == "name.too.short"

  test "tPassword - min/max length":
    let data = [("pass", "12345678901")]
    withBag data:
      pass: tPassword"pass.error":
        min: 3 or "pass.short"
        max: 10 or "pass.long"
    do:
      check inputBag.isInvalid
      check inputBag.getErrors[0][1] == "pass.long"

  test "tTextarea - valid min/max":
    let data = [("msg", "hello")]
    withBag data:
      msg: tTextarea"msg.error":
        min: 2 or "msg.short"
        max: 10 or "msg.long"
    do:
      check inputBag.isValid

  test "tHidden - min/max":
    let data = [("token", "secret")]
    withBag data:
      token: tHidden"token.error":
        min: 3 or "token.short"
        max: 20 or "token.long"
    do:
      check inputBag.isValid

  test "tSearch - min/max":
    let data = [("q", "a")]
    withBag data:
      q: tSearch"q.error":
        min: 2 or "q.short"
    do:
      check inputBag.isInvalid
      check inputBag.getErrors[0][1] == "q.short"

  test "tTel - min/max":
    let data = [("phone", "+1234567890")]
    withBag data:
      phone: tTel"phone.error":
        min: 10 or "phone.short"
    do:
      check inputBag.isValid

suite "Email":
  test "valid email passes":
    let data = [("email", "test@example.com")]
    withBag data:
      email: tEmail"auth.error.email"
    do:
      check inputBag.isValid

  test "invalid email fails":
    let data = [("email", "test@examplecom")]
    withBag data:
      email: tEmail"auth.error.email"
    do:
      check inputBag.isInvalid
      check inputBag.getErrors[0][1] == "auth.error.email"

  test "empty required email fails":
    let data = [("email", "")]
    withBag data:
      email: tEmail"auth.error.email"
    do:
      check inputBag.isInvalid

suite "Password Strength":
  test "weak password fails":
    let data = [("pass", "1234")]
    withBag data:
      pass: tPasswordStrength"weak.password"
    do:
      check inputBag.isInvalid
      check inputBag.getErrors[0][1] == "weak.password"

  test "strong password passes":
    let data = [("pass", "/iwJN_zCO#@k")]
    withBag data:
      pass: tPasswordStrength"weak.password"
    do:
      check inputBag.isValid

suite "Checkbox and Radio":
  test "valid checkbox values pass":
    for val in ["0", "1", "on", "off", "true", "false", "unchecked", "checked"]:
      let data = [("cb", val)]
      withBag data:
        cb: tCheckbox"cb.invalid"
      do:
        check inputBag.isValid

  test "invalid checkbox fails":
    let data = [("cb", "yes")]
    withBag data:
      cb: tCheckbox"cb.invalid"
    do:
      check inputBag.isInvalid
      check inputBag.getErrors[0][1] == "cb.invalid"

  test "tRadio - valid values pass":
    let data = [("radio", "true")]
    withBag data:
      radio: tRadio"radio.invalid"
    do:
      check inputBag.isValid

suite "Date":
  test "valid date passes":
    let data = [("birthday", "2001-05-05")]
    withBag data:
      birthday: tDate"yyyy-MM-dd"
    do:
      check inputBag.isValid

  test "invalid date format fails":
    let data = [("birthday", "not-a-date")]
    withBag data:
      birthday: tDate"yyyy-MM-dd"
    do:
      check inputBag.isInvalid

suite "Select":
  test "valid option passes":
    let data = [("region", "kefalonia")]
    withBag data:
      region: tSelect"unknown.region":
        options: @["kefalonia", "paros"] or "unknown.region"
    do:
      check inputBag.isValid

  test "invalid option fails":
    let data = [("region", "ibiza")]
    withBag data:
      region: tSelect"unknown.region":
        options: @["kefalonia", "paros"] or "unknown.region"
    do:
      check inputBag.isInvalid
      check inputBag.getErrors[0][1] == "unknown.region"

suite "Color":
  test "valid hex color passes":
    let data = [("color", "#fff")]
    withBag data:
      color: tColor"color.invalid"
    do:
      check inputBag.isValid

  test "invalid color fails":
    let data = [("color", "notacolor")]
    withBag data:
      color: tColor"color.invalid"
    do:
      check inputBag.isInvalid

suite "Domain":
  test "valid domain passes":
    let data = [("domain", "example.com")]
    withBag data:
      domain: tDomain"domain.invalid"
    do:
      check inputBag.isValid

  test "invalid domain fails":
    let data = [("domain", "example")]
    withBag data:
      domain: tDomain"domain.invalid"
    do:
      check inputBag.isInvalid

suite "Encoding fields":
  test "tBase32":
    let valid = [("enc", "JBSWY3DP")]
    let invalid = [("enc", "not!!base32")]
    withBag valid:
      enc: tBase32"enc.invalid"
    do:
      check inputBag.isValid
    withBag invalid:
      enc: tBase32"enc.invalid"
    do:
      check inputBag.isInvalid

  test "tBase58":
    let valid = [("enc", "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")]
    let invalid = [("enc", "0OIl")]
    withBag valid:
      enc: tBase58"enc.invalid"
    do:
      check inputBag.isValid
    withBag invalid:
      enc: tBase58"enc.invalid"
    do:
      check inputBag.isInvalid

  test "tBase64":
    let valid = [("enc", "dGVzdA==")]
    let invalid = [("enc", "@@@")]
    withBag valid:
      enc: tBase64"enc.invalid"
    do:
      check inputBag.isValid
    withBag invalid:
      enc: tBase64"enc.invalid"
    do:
      check inputBag.isInvalid

  test "tHex":
    let valid = [("h", "ff00")]
    let invalid = [("h", "xyz")]
    withBag valid:
      h: tHex"hex.invalid"
    do:
      check inputBag.isValid
    withBag invalid:
      h: tHex"hex.invalid"
    do:
      check inputBag.isInvalid

suite "Credit card":
  test "tCard - valid Luhn passes":
    let data = [("cc", "4111111111111111")]
    withBag data:
      cc: tCard"cc.invalid"
    do:
      check inputBag.isValid

  test "tCard - invalid fails":
    let data = [("cc", "1234567890")]
    withBag data:
      cc: tCard"cc.invalid"
    do:
      check inputBag.isInvalid

suite "EAN":
  test "tEAN - valid EAN-13 passes":
    let data = [("ean", "5901234123457")]
    withBag data:
      ean: tEAN"ean.invalid"
    do:
      check inputBag.isValid

  test "tEAN - invalid fails":
    let data = [("ean", "123")]
    withBag data:
      ean: tEAN"ean.invalid"
    do:
      check inputBag.isInvalid

suite "IP Address":
  test "tIP - valid IPv4 passes":
    let data = [("ip", "192.168.1.1")]
    withBag data:
      ip: tIP"ip.invalid"
    do:
      check inputBag.isValid

  test "tIP - invalid fails":
    let data = [("ip", "999.999.999.999")]
    withBag data:
      ip: tIP"ip.invalid"
    do:
      check inputBag.isInvalid

suite "JSON":
  test "tJSON - valid JSON passes":
    let data = [("json", """{"key":"value"}""")]
    withBag data:
      json: tJSON"json.invalid"
    do:
      check inputBag.isValid

  test "tJSON - invalid JSON fails":
    let data = [("json", "not json")]
    withBag data:
      json: tJSON"json.invalid"
    do:
      check inputBag.isInvalid

suite "MD5":
  test "tMD5 - valid MD5 passes":
    let data = [("hash", "d41d8cd98f00b204e9800998ecf8427e")]
    withBag data:
      hash: tMD5"hash.invalid"
    do:
      check inputBag.isValid

  test "tMD5 - invalid fails":
    let data = [("hash", "notmd5")]
    withBag data:
      hash: tMD5"hash.invalid"
    do:
      check inputBag.isInvalid

suite "Port":
  test "tPort - valid port passes":
    let data = [("port", "8080")]
    withBag data:
      port: tPort"port.invalid"
    do:
      check inputBag.isValid

  test "tPort - invalid port fails":
    let data = [("port", "99999")]
    withBag data:
      port: tPort"port.invalid"
    do:
      check inputBag.isInvalid

suite "String classification":
  test "tAlpha":
    let valid = [("s", "hello")]
    let invalid = [("s", "hello123")]
    withBag valid:
      s: tAlpha"alpha.invalid"
    do:
      check inputBag.isValid
    withBag invalid:
      s: tAlpha"alpha.invalid"
    do:
      check inputBag.isInvalid

  test "tAlphanumeric":
    let valid = [("s", "hello123")]
    let invalid = [("s", "hello!")]
    withBag valid:
      s: tAlphanumeric"alnum.invalid"
    do:
      check inputBag.isValid
    withBag invalid:
      s: tAlphanumeric"alnum.invalid"
    do:
      check inputBag.isInvalid

  test "tUppercase":
    let valid = [("s", "HELLO")]
    let invalid = [("s", "Hello")]
    withBag valid:
      s: tUppercase"upper.invalid"
    do:
      check inputBag.isValid
    withBag invalid:
      s: tUppercase"upper.invalid"
    do:
      check inputBag.isInvalid

  test "tLowercase":
    let valid = [("s", "hello")]
    let invalid = [("s", "Hello")]
    withBag valid:
      s: tLowercase"lower.invalid"
    do:
      check inputBag.isValid
    withBag invalid:
      s: tLowercase"lower.invalid"
    do:
      check inputBag.isInvalid

suite "Boolean and numeric":
  test "tBool":
    let valid = [("b", "true")]
    let invalid = [("b", "yes")]
    withBag valid:
      b: tBool"bool.invalid"
    do:
      check inputBag.isValid
    withBag invalid:
      b: tBool"bool.invalid"
    do:
      check inputBag.isInvalid

  test "tFloat":
    let valid = [("f", "3.14")]
    let invalid = [("f", "abc")]
    withBag valid:
      f: tFloat"float.invalid"
    do:
      check inputBag.isValid
    withBag invalid:
      f: tFloat"float.invalid"
    do:
      check inputBag.isInvalid

  test "tNumber - valid int passes":
    let data = [("n", "42")]
    withBag data:
      n: tNumber"num.invalid"
    do:
      check inputBag.isValid

  test "tNumber - invalid fails":
    let data = [("n", "12.5")]
    withBag data:
      n: tNumber"num.invalid"
    do:
      check inputBag.isInvalid

  test "tRange - valid int passes":
    let data = [("r", "50")]
    withBag data:
      r: tRange"range.invalid"
    do:
      check inputBag.isValid

suite "UUID":
  test "tUUID - valid UUID passes":
    let data = [("uuid", "550e8400-e29b-41d4-a716-446655440000")]
    withBag data:
      uuid: tUUID"uuid.invalid"
    do:
      check inputBag.isValid

  test "tUUID - invalid fails":
    let data = [("uuid", "not-uuid")]
    withBag data:
      uuid: tUUID"uuid.invalid"
    do:
      check inputBag.isInvalid

suite "URL":
  test "tURL - valid URL passes":
    let data = [("url", "https://example.com")]
    withBag data:
      url: tURL"url.invalid"
    do:
      check inputBag.isValid

  test "tURL - invalid fails":
    let data = [("url", "not-a-url")]
    withBag data:
      url: tURL"url.invalid"
    do:
      check inputBag.isInvalid

suite "Date-like HTML fields":
  test "tMonth":
    let valid = [("m", "2023-12")]
    let invalid = [("m", "2023-13")]
    withBag valid:
      m: tMonth"month.invalid"
    do:
      check inputBag.isValid
    withBag invalid:
      m: tMonth"month.invalid"
    do:
      check inputBag.isInvalid

  test "tTime":
    let valid = [("t", "14:30")]
    let invalid = [("t", "25:00")]
    withBag valid:
      t: tTime"time.invalid"
    do:
      check inputBag.isValid
    withBag invalid:
      t: tTime"time.invalid"
    do:
      check inputBag.isInvalid

  test "tTime with seconds":
    let data = [("t", "14:30:45")]
    withBag data:
      t: tTime"time.invalid"
    do:
      check inputBag.isValid

  test "tWeek":
    let valid = [("w", "2023-W05")]
    let invalid = [("w", "2023-W54")]
    withBag valid:
      w: tWeek"week.invalid"
    do:
      check inputBag.isValid
    withBag invalid:
      w: tWeek"week.invalid"
    do:
      check inputBag.isInvalid

suite "Datalist":
  test "tDatalist - min/max":
    let data = [("color", "red")]
    withBag data:
      color: tDatalist"color.error":
        min: 2 or "color.short"
        max: 10 or "color.long"
    do:
      check inputBag.isValid

suite "Regex":
  test "tRegex - valid pattern passes":
    let data = [("pattern", "^[a-z]+$")]
    withBag data:
      pattern: tRegex"regex.invalid"
    do:
      check inputBag.isValid

  test "tRegex - invalid pattern fails":
    let data = [("pattern", "[")]
    withBag data:
      pattern: tRegex"regex.invalid"
    do:
      check inputBag.isInvalid

suite "CSRF":
  test "tCSRF - non-empty passes":
    let data = [("csrf", "some-token")]
    withBag data:
      csrf: tCSRF"csrf.invalid":
        min: 5 or "csrf.short"
    do:
      check inputBag.isValid

  test "tCSRF - empty required fails":
    let data = [("csrf", "")]
    withBag data:
      csrf: tCSRF"csrf.invalid"
    do:
      check inputBag.isInvalid

suite "Country-like fields":
  test "tCountry - min/max":
    let data = [("c", "Greece")]
    withBag data:
      c: tCountry"country.error"
    do:
      check inputBag.isValid

  test "tCountryState - min/max":
    let data = [("s", "Attica")]
    withBag data:
      s: tCountryState"state.error"
    do:
      check inputBag.isValid

  test "tCountryCapital":
    let data = [("cap", "Athens")]
    withBag data:
      cap: tCountryCapital"cap.error"
    do:
      check inputBag.isValid

  test "tCurrency":
    let data = [("cur", "EUR")]
    withBag data:
      cur: tCurrency"cur.error"
    do:
      check inputBag.isValid

suite "Optional fields":
  test "optional field missing is valid":
    let data: seq[(string, string)] = @[]
    withBag data:
      *remember: tCheckbox
    do:
      check inputBag.isValid

  test "optional field present and valid":
    let data = [("remember", "true")]
    withBag data:
      *remember: tCheckbox
    do:
      check inputBag.isValid

suite "Required field missing":
  test "missing required field fails":
    let data: seq[(string, string)] = @[]
    withBag data:
      email: tEmail"email.required"
    do:
      check inputBag.isInvalid
      check inputBag.getErrors[0][1] == "email.required"

suite "Callback validation":
  test "callback passes for valid input":
    let data = [("csrf", "valid-token")]
    withBag data:
      csrf -> callback do(input: string) -> bool:
        result = input == "valid-token"
    do:
      check inputBag.isValid

  test "callback fails for invalid input":
    let data = [("csrf", "bad-token")]
    withBag data:
      csrf -> callback do(input: string) -> bool:
        result = input == "valid-token"
    do:
      check inputBag.isInvalid

suite "File":
  test "tFile is currently not implemented":
    let data = [("file", "some-content")]
    withBag data:
      file: tFile"file.error"
    do:
      check inputBag.isValid
