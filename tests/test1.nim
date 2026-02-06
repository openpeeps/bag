import std/[unittest, tables, times]
import bag

test "can find errors":
  var fields = @[
    ("email", "test@examplecom"),
    ("password", ""),
    ("message", "Lorem ipsum something better than that")
  ]

  bag fields:
    text: tText"auth.error.name"
    email: tEmail"auth.error.email"
    password: tPassword"auth.error.password"
    # message: tTextarea"comment.message.empty":
    #   min: 10 or "comment.message.min"
    #   max: 20 or "comment.message.max"
    # *remember: tCheckbox
  # do:
  #   check inputBag.isValid == false
  #   check inputBag.getErrors[0][1] == "auth.error.email"
  #   check inputBag.getErrors[1][1] == "auth.error.password"
  #   check inputBag.getErrors[2][1] == "comment.message.max"

test "check tDate":
  let invalid = [("birthday", "1999-05-05")]
  let valid = [("birthday", "2001-05-05")]
  for data in [invalid, valid]:
    bag data:
      birthday: tDate"yyyy-MM-dd"
      # min: "2000-12-01" or "invalid.date.min"
      # max: "2010-05-06" or "invalid.date.min"
    # do:
      # check(inputBag.getErrors[0][1] == "invalid.date.min")

test "check tPasswordStrength":
  for data in [[("mypassword", "1234")], [("mypassword", "/iwJN_zCO#@k")]]:
    bag data:
      mypassword: tPasswordStrength"weak.password"
    do:
      check inputBag.getErrors[0][1] == "weak.password"

test "check TCheckbox":
  let invalid = [("mycheckbox", "yes")]
  let valid = [("mycheckbox", "true")]
  proc checkValid() =
    bag valid:
      mycheckbox: tCheckbox"invalid.checkbox"
    # check Bag.isValid == true
    # check(Bag.getErrors.len == 0)

  proc checkInvalid() =
    bag invalid:
      mycheckbox: tCheckbox"invalid.checkbox"
    # check Bag.isValid == false
    # check(Bag.getErrors.len == 1)
    # check(Bag.getErrors[0][1] == "invalid.checkbox")

  checkValid()
  checkInvalid()

# test "check tSelect":
#   for data in [[("region", "ibiza")], [("region", "kefalonia")]]:
#     bag data:
#       region: tSelect:
#         options: ["kefalonia", "paros"] or "unknown.region"
#     # if not Bag.isValid:
#       # check Bag.getErrors[0][1] == "unknown.region"

# test "check tPasswordStrength":
#   let invalid = [("mypass", "sunandmoon12")]
#   let valid = [("mypass", "x6y2C8Dt5Lgg")]
  
#   proc checkValid() =
#     bag valid:
#       mypass: tPasswordStrength or "invalid.pass"
#     # check Bag.isValid == true
#     # check(Bag.getErrors.len == 0)

#   proc checkInvalid() =
#     bag invalid:
#       mypass: tPasswordStrength or "invalid.pass"
#     # check Bag.isValid == false
#     # check(Bag.getErrors.len == 1)
#     # check(Bag.getErrors[0][1] == "invalid.pass")

#   checkValid()
#   checkInvalid()