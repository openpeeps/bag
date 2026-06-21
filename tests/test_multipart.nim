import std/[unittest, strutils]
import bag
import multipart

const boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"

proc makeMultipartBody(fields: seq[(string, string, string)]): string =
  ## Build a multipart body. Each tuple: (fieldName, value, filename)
  ## If filename is empty, treated as text field
  for (name, value, filename) in fields:
    result.add "--" & boundary & "\r\n"
    if filename.len > 0:
      result.add "Content-Disposition: form-data; name=\"" & name & "\"; filename=\"" & filename & "\"\r\n"
      result.add "Content-Type: application/octet-stream\r\n\r\n"
    else:
      result.add "Content-Disposition: form-data; name=\"" & name & "\"\r\n\r\n"
    result.add value & "\r\n"
  result.add "--" & boundary & "--\r\n"

let ct = "multipart/form-data; boundary=" & boundary

# PNG magic bytes (8 bytes)
const pngMagic = "\x89\x50\x4e\x47\x0d\x0a\x1a\x0a"

suite "multipartBag - text fields":
  test "validates email and text fields":
    let body = makeMultipartBody(@[
      ("email", "test@example.com", ""),
      ("name", "John", ""),
    ])
    multipartBag body, ct:
      email: tEmail"auth.error.email"
      name: tText"name.error":
        min: 2 or "name.short"
    do:
      check inputBag.isValid

  test "fails invalid email":
    let body = makeMultipartBody(@[
      ("email", "not-an-email", ""),
    ])
    multipartBag body, ct:
      email: tEmail"auth.error.email"
    do:
      check inputBag.isInvalid
      check inputBag.getErrors[0][1] == "auth.error.email"

  test "missing required field fails":
    let body = makeMultipartBody(@[
      ("name", "John", ""),
    ])
    multipartBag body, ct:
      email: tEmail"email.required"
      name: tText"name.error"
    do:
      check inputBag.isInvalid
      let errs = inputBag.getErrors
      check errs[0][1] == "email.required"

  test "optional field missing is valid":
    let body = makeMultipartBody(@[
      ("email", "test@example.com", ""),
    ])
    multipartBag body, ct:
      email: tEmail"auth.error.email"
      *remember: tCheckbox
    do:
      check inputBag.isValid

suite "multipartBag - file fields":
  test "png file passes allowFileTypes":
    let body = makeMultipartBody(@[
      ("avatar", pngMagic & "extra data for magic detection", "image.png"),
    ])
    multipartBag body, ct:
      avatar: tFile"avatar.invalid":
        allowFileTypes: @["image/png"] or "bad.type"
    do:
      check inputBag.isValid

  test "wrong file type fails":
    let body = makeMultipartBody(@[
      ("avatar", "plain text not an image at all", "file.txt"),
    ])
    multipartBag body, ct:
      avatar: tFile"avatar.invalid":
        allowFileTypes: @["image/png"] or "bad.type"
    do:
      check inputBag.isInvalid

  test "mixed text and file fields":
    let body = makeMultipartBody(@[
      ("email", "user@example.com", ""),
      ("avatar", pngMagic & "extra padding data to avoid parser boundary overlap with magic bytes", "avatar.png"),
    ])
    multipartBag body, ct:
      email: tEmail"auth.error.email"
      avatar: tFile"avatar.invalid":
        allowFileTypes: @["image/png"] or "bad.type"
    do:
      check inputBag.isValid

suite "multipartStreamedBag":
  test "streaming validates text fields":
    let body = makeMultipartBody(@[
      ("email", "test@example.com", ""),
    ])
    let feeder = proc(ms: var MultipartStreamer): bool =
      ms.feed(body)
      return false
    multipartStreamedBag feeder, ct:
      email: tEmail"auth.error.email"
    do:
      check inputBag.isValid

  test "streaming fails invalid field":
    let body = makeMultipartBody(@[
      ("email", "bad", ""),
    ])
    let feeder = proc(ms: var MultipartStreamer): bool =
      ms.feed(body)
      return false
    multipartStreamedBag feeder, ct:
      email: tEmail"auth.error.email"
    do:
      check inputBag.isInvalid

  test "streaming file validation":
    let body = makeMultipartBody(@[
      ("avatar", pngMagic & "padding to avoid boundary overlap with magic bytes", "img.png"),
    ])
    let feeder = proc(ms: var MultipartStreamer): bool =
      ms.feed(body)
      return false
    multipartStreamedBag feeder, ct:
      avatar: tFile"avatar.invalid":
        allowFileTypes: @["image/png"] or "bad.type"
    do:
      check inputBag.isValid
