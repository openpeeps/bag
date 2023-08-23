import std/[unittest, tables, times]
import bag

test "can find errors":
  var fields = @[
    ("email", "test@examplecom"),
    ("password", ""),
    ("message", "Lorem ipsum something better than that")
  ]

  newBag fields:
    text: tText or "auth.error.name"
    email: tEmail or "auth.error.email"
    password: tPassword or "auth.error.password"
    message: tTextarea or "comment.message.empty":
      min: 10 or "comment.message.min"
      max: 20 or "comment.message.max"
    *remember: tCheckbox

  check Bag.isValid == false
  check Bag.getErrors[0][1] == "auth.error.email"
  check Bag.getErrors[1][1] == "auth.error.password"
  check Bag.getErrors[2][1] == "comment.message.max"

test "check tDate":
  let invalid = [("birthday", "1999-05-05")]
  let valid = [("birthday", "2001-05-05")]
  for data in [invalid, valid]:
    newBag data:
      birthday: tDate("yyyy-MM-dd") or "invalid.date":
        min: "2000-12-01" or "invalid.date.min"
        max: "2010-05-06" or "invalid.date.min"
    if not Bag.isValid:
      check(Bag.getErrors[0][1] == "invalid.date.min")

test "check tPassword":
  for data in [[("mypassword", "1234")], [("mypassword", "/iwJN_zCO#@k")]]:
    newBag data:
      mypassword: tPassword or "requires.password":
        min: 10 or "invalid.password.min"
        max: 13 or "invalid.password.max"
    if not Bag.isValid:
      check Bag.getErrors[0][1] == "invalid.password.min"

test "check tFile":
  ##

test "check TCheckbox":
  let invalid = [("mycheckbox", "yes")]
  let valid = [("mycheckbox", "true")]
  proc checkValid() =
    newBag valid:
      mycheckbox: tCheckbox or "invalid.checkbox"
    check Bag.isValid == true
    check(Bag.getErrors.len == 0)

  proc checkInvalid() =
    newBag invalid:
      mycheckbox: tCheckbox or "invalid.checkbox"
    check Bag.isValid == false
    check(Bag.getErrors.len == 1)
    check(Bag.getErrors[0][1] == "invalid.checkbox")

  checkValid()
  checkInvalid()

test "check tSelect":
  for data in [[("region", "ibiza")], [("region", "kefalonia")]]:
    newBag data:
      region: tSelect:
        options: ["kefalonia", "paros"] or "unknown.region"
    if not Bag.isValid:
      check Bag.getErrors[0][1] == "unknown.region"

test "check tPasswordStrength":
  let invalid = [("mypass", "sunandmoon12")]
  let valid = [("mypass", "x6y2C8Dt5Lgg")]
  
  proc checkValid() =
    newBag valid:
      mypass: tPasswordStrength or "invalid.pass"
    check Bag.isValid == true
    check(Bag.getErrors.len == 0)

  proc checkInvalid() =
    newBag invalid:
      mypass: tPasswordStrength or "invalid.pass"
    check Bag.isValid == false
    check(Bag.getErrors.len == 1)
    check(Bag.getErrors[0][1] == "invalid.pass")

  checkValid()
  checkInvalid()