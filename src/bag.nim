# Validate HTTP input data in a fancy way
# 
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/bag

import std/[macros, tables, times,
      strutils, json, math, streams]

import pkg/[valido, multipart, chroma]
import pkg/filetype/image
import pkg/filetype/audio

type
  TField* = enum
    tNone       # used to ignore `button`, `submit`, `reset` elements
    tCheckbox
    tColor
    tDate
    tDatalist
    tEmail
    tFile
    tHidden
    tMonth
    tNumber
    tPassword
    tTextarea
    tRadio
    tRange
    tSelect
    tSearch
    tTel
    tText
    tTime
    tUrl
    tWeek
    # special `text` based fields 
    tBase32
    tBase58
    tBase64
    tCard
    tCountry
    tCountryState
    tCountryCapital
    tCurrency
    tEAN
    tIP
    tJSON
    tMD5
    tPort
    tPasswordStrength
    tAlpha
    tAlphanumeric
    tUppercase
    tLowercase
    tBool
    tFloat
    tHex
    tRegex
    tUUID
    tCSRF
    tDomain

  MinMax* = ref object
    length*: int
    error*: string
  
  Rule* = object
    id*: string
    required*: bool
    case ftype*: TField
    of tSelect:
      selectOptions*: seq[string]
    of tFile:
      allowFileTypes*: (seq[string], string)
        ## A tuple containing a seq of mimetypes `@["image/png"]`
        ## and the error message
      allowMultiple*: bool
        ## Whether to allow multiple files
      maxFiles*: (uint, string)
        ## The maximum number of files that can be uploaded.
      minFileSize*, maxFileSize*: uint
        ## The min/max file size allowed in megabytes.
        ## Where `0` means unmetered size
    of tDate:
      formatDate*: string
      minDate*, maxDate*: tuple[isset: bool, error: string, date: DateTime]
    of tNone:
      callbackHandler*: proc(input: string): bool
    else: discard 
    error*: string
    min*, max*: MinMax

  Rules* = OrderedTable[string, Rule]
  
  InputBagType* = enum
    inputTypeUrlEncoded
    inputTypeMultipart

  InputBag* = ref object
    bagType: InputBagType
    failed: seq[(string, string)]
    rules: Rules

#
# Runtime API
#
proc newInputBag*(bagType: InputBagType): InputBag =
  InputBag(bagType: bagType)

proc isValid*(bag: InputBag): bool =
  result = bag.failed.len == 0

proc isInvalid*(bag: InputBag): bool =
  result = bag.failed.len != 0

proc getErrors*(bag: InputBag): seq[(string, string)] =
  result = bag.failed

proc addRule*(bag: InputBag, rule: Rule) =
  bag.rules[rule.id] = rule

template Fail() =
  add bag.failed, (rule.id, rule.error)

template Fail(error: string, altError = "") =
  add bag.failed, (rule.id, if error.len == 0: altError else: error)

template minMaxCheck() {.dirty.} =
  if rule.min != nil:
    if not valido.isMin(f[1], rule.min.length):
      Fail rule.min.error
  if rule.max != nil:
    if not valido.isMax(f[1], rule.max.length):
      Fail rule.max.error

proc validate*(bag: InputBag, data: openarray[(string, string)]) =
  ## Validate data
  for f in data:
    let
      k = f[0]
      v = f[1]
    if bag.rules.hasKey(k):
      let rule = bag.rules[k]
      case rule.ftype:
      of tEmail:
        if not valido.isEmpty v:
          if not valido.isEmail v: Fail
        elif rule.required: Fail
      of tPasswordStrength:
        if not valido.isEmpty v:
          if not valido.isStrongPassword v: Fail
        elif rule.required: Fail         
      of tCheckbox:
        if not valido.isEmpty v:
          if v notin ["0", "1", "off", "on", "false", "true", "unchecked", "checked"]: Fail
        elif rule.required: Fail
      of tDate:
        if not valido.isEmpty v:
          try:
            let inputDate = times.parse(v, rule.formatDate)
            if rule.minDate.isset:  # set a min date
              if inputDate >= rule.minDate.date == false:
                Fail rule.minDate.error, rule.error
            if rule.maxDate.isset:  # set a max date
              if inputDate <= rule.maxDate.date == false:
                Fail rule.maxDate.error, rule.error
          except TimeParseError, TimeFormatParseError:
            Fail
        elif rule.required: Fail
      of tText, tTextarea, tPassword:
        if not valido.isEmpty v:
          minMaxCheck()
        elif rule.required: Fail
      of tSelect:
        if not valido.isEmpty v:
          if v notin rule.selectOptions: Fail
        elif rule.required: Fail
      of tFile:
        # echo v
        # if not valido.isEmpty v:
          # echo v
        # elif rule.required: Fail
        discard
      of tDomain:
        if not valido.isEmpty v:
          if not valido.isDomain(v): Fail
        elif rule.required: Fail
      of tNone:
        assert rule.callbackHandler != nil
        if not rule.callbackHandler(v): Fail
      of tColor:
        if not valido.isEmpty v:
          if not valido.isColor(v): Fail
        elif rule.required: Fail
      else: discard # TODO add more filters
      bag.rules.del(k)
  for k, rule in pairs bag.rules:
    if rule.required:
      add bag.failed, (rule.id, rule.error)
  bag.rules.clear()

proc validate*(bag: InputBag, jsonData: JsonNode) =
  ## Validate input data using JSON format
  # todo handle bad format errors
  if likely(jsonData.kind == JObject):
    var data: seq[(string, string)]
    for k, v in jsonData:
      if likely(v.kind == JString):
        add data, (k, v.getStr)
      else: return
    bag.validate(data)

proc validateMultipart*(bag: InputBag, contentType,
    multipartBody: sink string
) =
  ## Validates a multipart body using `pkg/multipart`.
  ## 
  ## Thanks to `pkg/filetypes`, the `multipart` parser can
  ## validate the type based on magic numbers
  ## signature while writing file contents to a temporary path.
  ## 
  ## In this case, the multipart parser will parsing
  ## if the extracted signature is not in `allowFileTypes` sequence.
  var magicSignature: seq[byte]
  var fileCallback =
    proc(boundary: ptr Boundary, pos: int, c: ptr char): bool =
      if pos <= 4:
        add magicSignature, c[].byte
        return true
      # else:
        # echo magicSignature
        # echo magicSignature.isOgg
      result = true

  var mp = initMultipart(contentType)
  mp.parse(multipartBody)
  for boundary in mp:
    if boundary.dataType == MultipartFile:
      echo boundary.getPath
    else:
      echo boundary.value

#
# Compile time API
#
template handleFilters(node: NimNode) =
  case tField:
  of tDate:
    for c in node:
      let fieldStr = c[0].strVal
      if fieldStr notin ["min", "max"]:
        error("Unrecognized field $1 for $2" % [fieldStr, $tfield])
      let dateFormat = fieldType[1]
      if c[1][0].kind == nnkInfix:
        expectKind c[1][0][2], nnkStrLit # error message
        var dateTuple = nnkTupleConstr.newTree()
        dateTuple.add(
          newLit true,  # set isset status
          c[1][0][2],   # set error message
          newCall(
            ident "parse",
            c[1][0][1],
            dateFormat
          )
        )
        newRule.add(
          newColonExpr(
            ident(fieldStr & "Date"),
            dateTuple
          )
        )
      elif c[1][0].kind == nnKStrLit:
        var dateTuple = nnkTupleConstr.newTree()
        dateTuple.add(
          newLit true,  # set isset status
          newLit "",    # no error message
          newCall(
            ident "parse",
            c[1][0],
            dateFormat
          )
        )
        newRule.add(
          newColonExpr(
            ident(fieldStr & "Date"),
            dateTuple
          )
        )
    newRule.add(
      newColonExpr(
        ident "formatDate",
        fieldType[1]
      )
    )
  of tSelect:
    for c in node:
      if eqIdent(c[0], "options"):
        expectKind c[1], nnkStmtList
        if c[1][0].kind == nnkInfix:
          expectKind c[1][0][2], nnkStrLit # error message
          if c[1][0][1].kind == nnkPrefix:
            # handle options in a sequence
            newRule.add(
              newColonExpr(ident "selectOptions", c[1][0][1]),
              newColonExpr(ident "error", c[1][0][2])
            )
          elif c[1][0][1].kind == nnkBracket:
            # handle options in array
            newRule.add(
              newColonExpr(
                ident "selectOptions",
                nnkPrefix.newTree(ident "@", c[1][0][1])
              ),
              newColonExpr(ident "error", c[1][0][2])
            )
      else: error("Missing `options` for tSelect rule")
  of tFile:
    for c in node:
      expectKind(c, nnkCall)
      var filterVal = c[1]
      var filterMsg: NimNode
      if c[1][0].kind == nnkInfix:
        expectIdent(c[1][0][0], "?")
        expectKind(c[1][0][2], nnkStrLit)
        filterVal = c[1][0][1]
        filterMsg = c[1][0][2]
      if filterMsg != nil:
        add newRule, newColonExpr(c[0],
          nnkTupleConstr.newTree(filterVal, filterMsg)
        )
      else:
        add newRule, newColonExpr(c[0], filterVal)
  else:
    for c in node:
      expectKind(c, nnkCommand)
      # echo c.treeRepr
      # if eqIdent(c[0], "min") or eqIdent(c[0], "max"):
      #   # Setup ranges (min/max)
      #   expectKind(c[1], nnkInfix)
      #   expectKind(c[1][0], nnkIdent)
      #   newRule.add(
      #     newColonExpr(c[0],
      #       nnkObjConstr.newTree(
      #         ident "MinMax",
      #         newColonExpr(
      #           ident "length",
      #           c[1][0][1]
      #         ),
      #         newColonExpr(
      #           ident "error",
      #           c[1][0][2]
      #         )
      #       )
      #     )
      #   )

proc parseRule(rule: NimNode, isRequired = true): NimNode {.compileTime.} =
  var
    newRule = newTree(nnkObjConstr).add(ident "Rule")
    tfield: string
    id, ruleStmt: NimNode 
  if rule.kind == nnkCall:
    id = rule[0]
    ruleStmt = rule[1]
  elif rule.kind == nnkPrefix:
    id = rule[1]
    ruleStmt = rule[2]

  # if ruleStmt[0].kind == nnkDo:
  #   echo ruleStmt.treeRepr
  # todo

  for r in ruleStmt:
    expectKind(r, nnkCallStrLit)
    let fieldType = r[0]
    let msg = r[1]
    let tField = parseEnum[TField]($fieldType)
    newRule.add(
      newColonExpr(ident"id", newLit $id),
      newColonExpr(ident"ftype", ident $fieldType),
      newColonExpr(ident"required", newLit isRequired),
      newColonExpr(ident"error", msg)
    )
    if r.len == 3:
      expectKind(r[2], nnkStmtList)
      handleFilters(r[2])
  result = newRule

template parseBagRules(bagType: NimNode) {.dirty.} =
  expectKind rules, nnkStmtList
  var blockStmt = newStmtList()
  let varBagInstance =
    newVarStmt(
      ident"inputBag",
      newCall(
        ident"newInputBag",
        bagType
      )
    )
  var
    i = 0
    rulesIndex = newTable[string, int]()
    rulesList = newStmtList()
  for r in rules:
    case r.kind
    of nnkCall:
      # handle required fields
      let node = parseRule(r)
      add rulesList, newCall(ident"addRule", ident"inputBag", node)
      rulesIndex[r[0].strVal] = i
    of nnkPrefix:
      # handle optional fields
      if r[0].eqIdent"*":
        let node = parseRule(r, false)
        add rulesList, newCall(ident"addRule", ident"inputBag", node)
        rulesIndex[r[0].strVal] = i
    of nnkInfix:
      if r[0].eqIdent"->":
        expectKind(r[1], nnkIdent)
        expectKind(r[2], nnkIdent)
        if (r[2].strVal == "callback" and r.len == 4) and(r[3].kind == nnkDo):
          var newRule = newTree(nnkObjConstr).add(ident"Rule")
          var ruleCallbackHandle = newProc(body = r[3][^1])
          ruleCallbackHandle[3] = r[3][3] # copy return type and params
          newRule.add(
            newColonExpr(ident"id", newLit(r[1].strVal)),
            newColonExpr(ident"ftype", ident"tNone"),
            newColonExpr(ident"callbackHandler", ruleCallbackHandle)
          )
          rulesIndex[r[1].strVal] = i
          add rulesList, newCall(ident"addRule", ident"inputBag", newRule)
        else:
          if rulesIndex.hasKey(r[2].strVal):
            rulesIndex[r[1].strVal] = i
            add rulesList, rulesList[rulesIndex[r[2].strVal]]
          else:
            error("Trying to reference a rule that does not exist: $1" % [r[2].strVal])
    else: discard # todo compile-time error
    inc i

  blockStmt.add varBagInstance
  blockStmt.add rulesList

macro bag*(data: typed, rules: untyped, bodyFail: untyped = nil) =
  ## Create a new input bag validation at compile time.
  ##
  ## `data` expects a `seq[tuple[k, v: string]]`
  ## that represent submitted data from the current request.
  ##
  ## `rules` is used to define your rules at compile-time.
  runnableExamples:
    # dummy data containing a seq/openArray 
    # of tuples with key/value pairs
    let data = [
      ("email": "test@example.com"),
      ("password", "123admin"),
      ("remember", "on")
    ]
    bag data:
      email: tEmail"Invalid email address"
      password: tPasswordStrength"Weak password"
      *remember: tCheckbox  # optional field, default: off/false
    do:
      for err in inputBag.getErrors:
        echo err
  parseBagRules(ident"inputTypeUrlEncoded")

  blockStmt.add quote do:
    inputBag.validate(`data`)
  if bodyFail != nil:
    blockStmt.add quote do:
      # let inputData = `data.`
      if inputBag.isInvalid:
        `bodyFail`

  result = nnkBlockStmt.newTree(newEmptyNode(), blockStmt)
  when defined debugMacrosOpenPeepsBag:
    debugEcho result.repr

template withValidator*(x: typed, r: untyped, b: untyped = nil) =
  ## Create a new input bag validation at compile time.
  ## This is an alias for `bag` macro.
  bag(x, r, b)

macro multipartBag*(data, contentType: typed,
    rules: untyped,
    # chunkUploads: static bool = false,
    # chunkSize: static int = int(100^3),
    bodySuccess, bodyFail: untyped = nil,
  ) =
  ## Create a bag from multipart body
  ##
  ## `data` must be a multipart body from a request
  ## `contentType` the string version of `Content-Type` header
  ## 
  ## `rules` is used to define your rules at compile-time.
  # runnableExamples:
  #   let data = """
  #    """
  #   bag data:
  #     email: tEmail"Invalid email address"
  #     password: tPasswordStrength"Weak password"
  #     *remember: tCheckbox  # optional field, default: off/false
  #   do:
  #     for err in inputBag.getErrors:
  #       echo err
  parseBagRules(ident"inputTypeMultipart")
  blockStmt.add quote do:
    inputBag.validateMultipart(`contentType`, `data`)
  if bodySuccess != nil:
    add blockStmt, quote do:
      `bodySuccess`
  if bodyFail != nil:
    add blockStmt, quote do:
      if inputBag.isInvalid:
        `bodyFail`
  result = nnkBlockStmt.newTree(newEmptyNode(), blockStmt)
  when defined debugMacrosOpenPeepsBag:
    debugEcho result.repr

macro multipartChunkedBag*(data, contentType: typed,
    rules: untyped, 
    chunkSize: static int = int(100^3),
    bodySuccess, bodyFail
  )=
  ## Create a bag from a chunked multipart body
  discard