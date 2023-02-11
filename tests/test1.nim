import std/[unittest, tables, times]
import bag

test "can find errors":
  var fields = @[
    ("email", "test@examplecom"),
    ("password", ""),
    ("message", "Lorem ipsum something better than that")
  ]

  newBag fields:
    text: TText or "auth.error.name"
    email: TEmail or "auth.error.email"
    password: TPassword or "auth.error.password"
    message: TTextarea or "comment.message.empty":
      min: 10 or "comment.message.min"
      max: 20 or "comment.message.max"
    *remember: TCheckbox

  check Bag.isValid == false
  check Bag.getErrors[0][1] == "auth.error.email"
  check Bag.getErrors[1][1] == "auth.error.password"
  check Bag.getErrors[2][1] == "comment.message.max"

test "check TDate":
  let invalid = [("birthday", "1999-05-05")]
  let valid = [("birthday", "2001-05-05")]
  for data in [invalid, valid]:
    newBag data:
      birthday: TDate("yyyy-MM-dd") or "invalid.date":
        min: "2000-12-01" or "invalid.date.min"
        max: "2010-05-06" or "invalid.date.min"
    if not Bag.isValid:
      check(Bag.getErrors[0][1] == "invalid.date.min")

test "check TCheckbox":
  let invalid = [("mycheckbox", "yes")]
  let valid = [("mycheckbox", "true")]
  proc checkValid() =
    newBag valid:
      mycheckbox: TCheckbox or "invalid.checkbox"
    check Bag.isValid == true
    check(Bag.getErrors.len == 0)

  proc checkInvalid() =
    newBag invalid:
      mycheckbox: TCheckbox or "invalid.checkbox"
    check Bag.isValid == false
    check(Bag.getErrors.len == 1)
    check(Bag.getErrors[0][1] == "invalid.checkbox")

  checkValid()
  checkInvalid()

test "check TPasswordStrength":
  let invalid = [("mypass", "sunandmoon12")]
  let valid = [("mypass", "x6y2C8Dt5Lgg")]
  
  proc checkValid() =
    newBag valid:
      mypass: TPasswordStrength or "invalid.pass"
    check Bag.isValid == true
    check(Bag.getErrors.len == 0)

  proc checkInvalid() =
    newBag invalid:
      mypass: TPasswordStrength or "invalid.pass"
    check Bag.isValid == false
    check(Bag.getErrors.len == 1)
    check(Bag.getErrors[0][1] == "invalid.pass")

  checkValid()
  checkInvalid()