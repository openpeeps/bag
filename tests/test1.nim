import std/[unittest, tables]
import bag

var errorMessages = toTable({
  "auth.error.name": "Please provide a name",
  "auth.error.email": "Invalid email address",
  "auth.error.password": "Invalid password",
  "comment.message.empty": "Missing a message",
  "comment.message.min": "Min 80 characters",
  "comment.message.max": "Max 120 characters"
})

proc i18n(key: string): string =
  result = errorMessages[key]

test "can find errors":
  var fields = @[
    ("email", "test@examplecom"),
    ("password", "123admin"),
    ("message", "Lorem ipsum something better than that")
  ]

  newBag fields:
    text: TText or "auth.error.name"
    email: TEmail or "auth.error.email"
    password: TPassword or "auth.error.password":
      min: 8 or "auth.error.password.min"
    message: TTextarea or "comment.message.empty":
      min: 10 or "comment.message.min"
      max: 20 or "comment.message.max"
    *remember: TCheckbox

  check Bag.isValid == false
  check Bag.getErrors[0][1] == "auth.error.email"
  check Bag.getErrors[1][1] == "auth.error.password"
  check Bag.getErrors[2][1] == "comment.message.max"