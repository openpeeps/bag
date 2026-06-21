# Validate HTTP input data in a fancy way
# 
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/bag

import std/[macros, tables, times,
            strutils, json, math]

import pkg/[valido, multipart, openparser/regex, filetype]

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
    of tDate, tMonth, tTime, tWeek:
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
          else: minMaxCheck()
        elif rule.required: Fail
      of tPasswordStrength:
        if not valido.isEmpty v:
          if not valido.isStrongPassword v: Fail
          else: minMaxCheck()
        elif rule.required: Fail
      of tCheckbox, tRadio:
        if not valido.isEmpty v:
          if v notin ["0", "1", "off", "on", "false", "true", "unchecked", "checked"]: Fail
        elif rule.required: Fail
      of tDate:
        if not valido.isEmpty v:
          try:
            let inputDate = times.parse(v, rule.formatDate)
            if rule.minDate.isset:
              if inputDate >= rule.minDate.date == false:
                Fail rule.minDate.error, rule.error
            if rule.maxDate.isset:
              if inputDate <= rule.maxDate.date == false:
                Fail rule.maxDate.error, rule.error
          except TimeParseError, TimeFormatParseError:
            Fail
        elif rule.required: Fail
      of tText, tTextarea, tPassword, tHidden, tSearch, tTel:
        if not valido.isEmpty v:
          minMaxCheck()
        elif rule.required: Fail
      of tSelect:
        if not valido.isEmpty v:
          if v notin rule.selectOptions: Fail
        elif rule.required: Fail
      of tFile:
        discard
      of tNone:
        assert rule.callbackHandler != nil
        if not rule.callbackHandler(v): Fail
      of tColor:
        if not valido.isEmpty v:
          if not valido.isColor(v): Fail
        elif rule.required: Fail
      of tDomain:
        if not valido.isEmpty v:
          if not valido.isDomain(v): Fail
          else: minMaxCheck()
        elif rule.required: Fail
      of tBase32:
        if not valido.isEmpty v:
          if not valido.isBase32(v): Fail
          else: minMaxCheck()
        elif rule.required: Fail
      of tBase58:
        if not valido.isEmpty v:
          if not valido.isBase58(v): Fail
          else: minMaxCheck()
        elif rule.required: Fail
      of tBase64:
        if not valido.isEmpty v:
          if not valido.isBase64(v): Fail
          else: minMaxCheck()
        elif rule.required: Fail
      of tCard:
        if not valido.isEmpty v:
          if not valido.isCard(v): Fail
          else: minMaxCheck()
        elif rule.required: Fail
      of tEAN:
        if not valido.isEmpty v:
          if not valido.isEAN(v).status: Fail
        elif rule.required: Fail
      of tIP:
        if not valido.isEmpty v:
          if not (valido.isIP4(v) or valido.isIP6(v)): Fail
          else: minMaxCheck()
        elif rule.required: Fail
      of tJSON:
        if not valido.isEmpty v:
          if not valido.isJSON(v): Fail
          else: minMaxCheck()
        elif rule.required: Fail
      of tMD5:
        if not valido.isEmpty v:
          if not valido.isMD5(v): Fail
          else: minMaxCheck()
        elif rule.required: Fail
      of tPort:
        if not valido.isEmpty v:
          if not valido.isPort(v): Fail
          else: minMaxCheck()
        elif rule.required: Fail
      of tAlpha:
        if not valido.isEmpty v:
          if not valido.isAlpha(v): Fail
          else: minMaxCheck()
        elif rule.required: Fail
      of tAlphanumeric:
        if not valido.isEmpty v:
          if not valido.isAlphaNumeric(v): Fail
          else: minMaxCheck()
        elif rule.required: Fail
      of tUppercase:
        if not valido.isEmpty v:
          if not valido.isUppercase(v): Fail
          else: minMaxCheck()
        elif rule.required: Fail
      of tLowercase:
        if not valido.isEmpty v:
          if not valido.isLowercase(v): Fail
          else: minMaxCheck()
        elif rule.required: Fail
      of tBool:
        if not valido.isEmpty v:
          if not valido.isBoolean(v): Fail
        elif rule.required: Fail
      of tFloat:
        if not valido.isEmpty v:
          if not valido.isFloat(v): Fail
          else: minMaxCheck()
        elif rule.required: Fail
      of tHex:
        if not valido.isEmpty v:
          if not valido.isHexStr(v): Fail
          else: minMaxCheck()
        elif rule.required: Fail
      of tUUID:
        if not valido.isEmpty v:
          if not valido.isUUID(v): Fail
          else: minMaxCheck()
        elif rule.required: Fail
      of tNumber, tRange:
        if not valido.isEmpty v:
          if not valido.isInt(v): Fail
          else: minMaxCheck()
        elif rule.required: Fail
      of tURL:
        if not valido.isEmpty v:
          if "://" notin v: Fail
          else:
            let parts = v.split("://")
            if parts[0].len == 0 or parts[^1].len == 0: Fail
            else: minMaxCheck()
        elif rule.required: Fail
      of tDatalist:
        if not valido.isEmpty v:
          minMaxCheck()
        elif rule.required: Fail
      of tMonth:
        if not valido.isEmpty v:
          if v.len != 7 or v[4] != '-': Fail
          else:
            try:
              let m = parseInt(v[5..6])
              if m < 1 or m > 12: Fail
            except ValueError: Fail
        elif rule.required: Fail
      of tTime:
        if not valido.isEmpty v:
          let parts = v.split(':')
          if parts.len notin [2, 3]: Fail
          else:
            try:
              let h = parseInt(parts[0])
              let m = parseInt(parts[1])
              if h < 0 or h > 23 or m < 0 or m > 59: Fail
              elif parts.len == 3:
                let s = parseInt(parts[2])
                if s < 0 or s > 59: Fail
            except ValueError: Fail
        elif rule.required: Fail
      of tWeek:
        if not valido.isEmpty v:
          if v.len != 8 or v[4] != '-' or v[5] != 'W': Fail
          else:
            try:
              let w = parseInt(v[6..7])
              if w < 1 or w > 53: Fail
            except ValueError: Fail
        elif rule.required: Fail
      of tCountry, tCountryState, tCountryCapital, tCurrency:
        if not valido.isEmpty v:
          minMaxCheck()
        elif rule.required: Fail
      of tRegex:
        if not valido.isEmpty v:
          try:
            discard regex.compile(v)
            minMaxCheck()
          except: Fail
        elif rule.required: Fail
      of tCSRF:
        if not valido.isEmpty v:
          minMaxCheck()
        elif rule.required: Fail
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
  var textFields: seq[(string, string)]
  var fileCounts: Table[string, uint]

  var fileSigCallback: MultipartFileCallbackSignature =
    proc(boundary: ptr Boundary, pos: int, c: ptr char): MultipartFileSigantureState =
      if pos < 32:
        return stateMoreMagic
      stateValidMagic

  var mp = initMultipart(contentType)
  mp.fileSignatureCallback = fileSigCallback
  mp.parse(multipartBody)

  for boundary in mp:
    if boundary.dataType == MultipartText:
      textFields.add (boundary.fieldName, boundary.value)
    elif boundary.dataType == MultipartFile and bag.rules.hasKey(boundary.fieldName):
      let rule = bag.rules[boundary.fieldName]
      if rule.ftype == tFile:
        if not rule.allowMultiple and fileCounts.getOrDefault(boundary.fieldName, 0'u) > 0'u:
          add bag.failed, (rule.id, rule.error)
        else:
          discard fileCounts.mgetOrPut(boundary.fieldName, 0'u)
          inc fileCounts[boundary.fieldName]

          if rule.maxFiles[0] > 0 and fileCounts[boundary.fieldName] > rule.maxFiles[0]:
            add bag.failed, (rule.id, rule.maxFiles[1])
          elif rule.minFileSize > 0 and boundary.fileSize < (rule.minFileSize * 1_000_000).int64:
            add bag.failed, (rule.id, rule.error)
          elif rule.maxFileSize > 0 and boundary.fileSize > (rule.maxFileSize * 1_000_000).int64:
            add bag.failed, (rule.id, rule.error)
          elif rule.allowFileTypes[0].len > 0:
            let detected = filetype.match(boundary.magicNumbers)
            var allowed = false
            for mt in rule.allowFileTypes[0]:
              if detected.mime.value == mt:
                allowed = true
                break
            if not allowed:
              add bag.failed, (rule.id, rule.allowFileTypes[1])
      bag.rules.del(boundary.fieldName)

  mp.cleanup()
  if textFields.len > 0:
    bag.validate(textFields)

proc validateMultipart*(bag: InputBag, contentType: string,
    multipartBody: sink seq[byte]
) =
  var bodyStr = newString(multipartBody.len)
  if multipartBody.len > 0:
    copyMem(addr bodyStr[0], addr multipartBody[0], multipartBody.len)
  bag.validateMultipart(contentType, bodyStr)

proc validateMultipart*(bag: InputBag, contentType: string,
    data: ptr UncheckedArray[byte], dataLen: int
) =
  var bodyStr = newString(dataLen)
  if dataLen > 0:
    copyMem(addr bodyStr[0], data, dataLen)
  bag.validateMultipart(contentType, bodyStr)

proc validateMultipartStreamed*(bag: InputBag, contentType: string,
    feeder: proc(ms: var MultipartStreamer): bool {.closure.}
) =
  var textFields: seq[(string, string)]
  var fileCounts: Table[string, uint]
  var fileSigCallback: MultipartFileCallbackSignature =
    proc(boundary: ptr Boundary, pos: int, c: ptr char): MultipartFileSigantureState =
      if pos < 32: return stateMoreMagic
      stateValidMagic

  var ms = newMultipartStreamer(contentType,
    fileSignatureCallback = fileSigCallback)
  while feeder(ms):
    discard

  for boundary in ms:
    if boundary.dataType == MultipartText:
      textFields.add (boundary.fieldName, boundary.value)
    elif boundary.dataType == MultipartFile and bag.rules.hasKey(boundary.fieldName):
      let rule = bag.rules[boundary.fieldName]
      if rule.ftype == tFile:
        if not rule.allowMultiple and fileCounts.getOrDefault(boundary.fieldName, 0'u) > 0'u:
          add bag.failed, (rule.id, rule.error)
        else:
          discard fileCounts.mgetOrPut(boundary.fieldName, 0'u)
          inc fileCounts[boundary.fieldName]
          if rule.maxFiles[0] > 0 and fileCounts[boundary.fieldName] > rule.maxFiles[0]:
            add bag.failed, (rule.id, rule.maxFiles[1])
          elif rule.minFileSize > 0 and boundary.fileSize < (rule.minFileSize * 1_000_000).int64:
            add bag.failed, (rule.id, rule.error)
          elif rule.maxFileSize > 0 and boundary.fileSize > (rule.maxFileSize * 1_000_000).int64:
            add bag.failed, (rule.id, rule.error)
          elif rule.allowFileTypes[0].len > 0:
            let detected = filetype.match(boundary.magicNumbers)
            var allowed = false
            for mt in rule.allowFileTypes[0]:
              if detected.mime.value == mt:
                allowed = true
                break
            if not allowed:
              add bag.failed, (rule.id, rule.allowFileTypes[1])
      bag.rules.del(boundary.fieldName)

  ms.cleanup()
  if textFields.len > 0:
    bag.validate(textFields)

#
# Compile time API
#
template handleFilters(node: NimNode) =
  case tField:
  of tDate, tMonth, tTime, tWeek:
    for c in node:
      let fieldStr = c[0].strVal
      if fieldStr notin ["min", "max"]:
        error("Unrecognized field $1 for $2" % [fieldStr, $tfield])
      let dateFormat = msg
      if c[1][0].kind == nnkInfix:
        expectKind c[1][0][2], nnkStrLit
        var dateTuple = nnkTupleConstr.newTree()
        dateTuple.add(
          newLit true,
          c[1][0][2],
          newCall(ident "parse", c[1][0][1], dateFormat)
        )
        newRule.add(
          newColonExpr(ident(fieldStr & "Date"), dateTuple)
        )
      elif c[1][0].kind == nnkStrLit:
        var dateTuple = nnkTupleConstr.newTree()
        dateTuple.add(
          newLit true,
          newLit "",
          newCall(ident "parse", c[1][0], dateFormat)
        )
        newRule.add(
          newColonExpr(ident(fieldStr & "Date"), dateTuple)
        )
  of tSelect:
    for c in node:
      if eqIdent(c[0], "options"):
        expectKind c[1], nnkStmtList
        if c[1][0].kind == nnkInfix:
          if c[1][0][1].kind == nnkPrefix:
            newRule.add(
              newColonExpr(ident "selectOptions", c[1][0][1])
            )
          elif c[1][0][1].kind == nnkBracket:
            newRule.add(
              newColonExpr(
                ident "selectOptions",
                nnkPrefix.newTree(ident "@", c[1][0][1])
              )
            )
      else: error("Missing `options` for tSelect rule")
  of tFile:
    for c in node:
      let expr = if c[1].kind == nnkStmtList: c[1][0] else: c[1]
      var filterVal = expr
      var filterMsg: NimNode
      if expr.kind == nnkInfix:
        filterVal = expr[1]
        filterMsg = expr[2]
      if filterMsg != nil:
        add newRule, newColonExpr(c[0],
          nnkTupleConstr.newTree(filterVal, filterMsg)
        )
      else:
        add newRule, newColonExpr(c[0], filterVal)
  else:
    for c in node:
      if eqIdent(c[0], "min") or eqIdent(c[0], "max"):
        let expr = if c[1].kind == nnkStmtList: c[1][0] else: c[1]
        expectKind(expr, nnkInfix)
        newRule.add(
          newColonExpr(c[0],
            nnkObjConstr.newTree(
              ident "MinMax",
              newColonExpr(ident "length", expr[1]),
              newColonExpr(ident "error", expr[2])
            )
          )
        )

proc parseRule(rule: NimNode, isRequired = true): NimNode {.compileTime.} =
  var
    newRule = newTree(nnkObjConstr).add(ident "Rule")
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

  let callNode = if ruleStmt.kind == nnkStmtList: ruleStmt[0] else: ruleStmt
  let (fieldType, msg, filterBody) =
    if callNode.kind == nnkIdent:
      (callNode, newLit(""), nil)
    elif callNode.kind in {nnkCallStrLit, nnkCall}:
      (callNode[0], callNode[1],
       if callNode.len == 3: callNode[2] else: nil)
    else:
      error("Unexpected field definition: " & $callNode.kind)
  let tField = parseEnum[TField]($fieldType)
  newRule.add(
    newColonExpr(ident"id", newLit $id),
    newColonExpr(ident"ftype", ident $fieldType),
    newColonExpr(ident"required", newLit isRequired),
    newColonExpr(ident"error", msg)
  )
  if filterBody != nil:
    expectKind(filterBody, nnkStmtList)
    handleFilters(filterBody)
  elif tField in {tDate, tMonth, tTime, tWeek}:
    newRule.add(newColonExpr(ident "formatDate", msg))
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

macro withBag*(data: typed, rules: untyped, bodyFail: untyped = nil) =
  ## Create a new input bag validation at compile time.
  ##
  ## `data` expects a `seq[tuple[k, v: string]]`
  ## that represent submitted data from the current request.
  ##
  ## `rules` is used to define your rules at compile-time.
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

macro multipartStreamedBag*(feeder, contentType: typed,
    rules: untyped, bodyFail: untyped = nil
  ) =
  ## Create a bag from a streaming multipart body using `MultipartStreamer`.
  ## `feeder` must be a `proc(ms: var MultipartStreamer): bool {.closure.}`
  ## that feeds multipart chunks and returns `true` to continue or
  ## `false` when done. File validation happens on-the-fly via signature callback.
  parseBagRules(ident"inputTypeMultipart")
  blockStmt.add quote do:
    inputBag.validateMultipartStreamed(`contentType`, `feeder`)
  if bodyFail != nil:
    add blockStmt, quote do:
      if inputBag.isInvalid:
        `bodyFail`
  result = nnkBlockStmt.newTree(newEmptyNode(), blockStmt)
  when defined debugMacrosOpenPeepsBag:
    debugEcho result.repr