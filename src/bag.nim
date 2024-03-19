# Validate HTTP input data in a fancy way
# 
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/bag

import pkg/valido
import std/[macros, tables, times, strutils]

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

  MinMax* = ref object
    length*: int
    error*: string

  Rule* = ref object
    id*: string
    required*: bool
    case ftype*: TField
    of tSelect:
      selectOptions*: seq[string]
    of tDate:
      formatDate*: string
      minDate*, maxDate*: tuple[isset: bool, error: string, date: DateTime]
    else: discard 
    error*: string
    min*, max*: MinMax

  Rules* = OrderedTable[string, Rule]
  
  InputBag* = ref object
    failed: seq[(string, string)]
    rules: Rules

#
# Runtime API
#
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

template minMaxCheck() =
  if rule.min != nil:
    if not valido.isMin(f[1], rule.min.length):
      Fail rule.min.error
  if rule.max != nil:
    if not valido.isMax(f[1], rule.max.length):
      Fail rule.max.error

proc validate*(bag: InputBag, data: openarray[(string, string)]) =
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
            let inputDate = parse(v, rule.formatDate)
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
          minMaxCheck
        elif rule.required: Fail
      of tSelect:
        if not valido.isEmpty v:
          if v notin rule.selectOptions: Fail
        elif rule.required: Fail
      else: discard # TODO add more filters
      bag.rules.del(k)
  for k, rule in pairs bag.rules:
    if rule.required:
      add bag.failed, (rule.id, rule.error)
  bag.rules.clear()

#
# Compile time API
#
template handleFilters(node: NimNode) =
  case parsedFieldType:
  of tDate:
    for c in node:
      let fieldStr = c[0].strVal
      if fieldStr notin ["min", "max"]:
        error("Unrecognized field $1 for $2" % [fieldStr, tfield])
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
  else:
    for c in node:
      if eqIdent(c[0], "min") or eqIdent(c[0], "max"):
        # Setup ranges (min/max)
        expectKind(c[1][0], nnkInfix)
        expectKind(c[1][0][0], nnkIdent)
        newRule.add(
          newColonExpr(c[0],
            nnkObjConstr.newTree(
              ident "MinMax",
              newColonExpr(
                ident "length",
                c[1][0][1]
              ),
              newColonExpr(
                ident "error",
                c[1][0][2]
              )
            )
          )
        )

proc parseRule(rule: NimNode, isRequired = true): NimNode {.compileTime.} =
  expectKind rule[0], nnkIdent
  expectKind rule[1], nnkStmtList
  var newRule = newTree(nnkObjConstr).add(ident "Rule")
  var tfield: string
  for r in rule[1]:
    if r.kind == nnkIdent:
      newRule.add(
        newColonExpr(ident "id", newLit rule[0].strVal),
        newColonExpr(ident "ftype", ident r.strVal),
        newColonExpr(ident "required", newLit isRequired),
      )
    elif r.kind == nnkInfix:
      let fieldType = r[1]
      if fieldType.kind == nnkIdent:
        tfield = fieldType.strVal
      elif fieldType.kind == nnkCall:
        tfield = fieldType[0].strVal
      if r[0].kind == nnkIdent:
        if r[0].strVal == "or":
          expectKind r[2], nnkStrLit
          newRule.add(
            newColonExpr(ident "id", newLit rule[0].strVal),
            newColonExpr(ident "ftype", ident tfield),
            newColonExpr(ident "required", newLit isRequired),
            newColonExpr(ident "error", r[2])
          )
      if r.len == 4:
        expectKind r[3], nnkStmtList
        let parsedFieldType = parseEnum[TField](tfield)
        handleFilters(r[3])
    elif r.kind == nnkCall:
      let fieldType = r[0]
      if fieldType.kind == nnkIdent:
        tfield = fieldType.strVal
      elif fieldType.kind == nnkCall:
        tfield = fieldType[0].strVal
      let parsedFieldType = parseEnum[TField](tfield)
      expectKind r[1], nnkStmtList
      newRule.add(
        newColonExpr(ident "id", newLit rule[0].strVal),
        newColonExpr(ident "ftype", r[0]),
        newColonExpr(ident "required", newLit isRequired),
      )
      handleFilters(r[1])
  result = newRule

macro bag*(data: typed, rules: untyped, bodyFail: untyped = nil) =
  ## Create a new input bag validation at compile time.
  ##
  ## `data` expects a `seq[tuple[k, v: string]]`
  ## that represent submitted data from the current request.
  ##
  ## `rules` is used to define your rules at compile-time.
  runnableExamples:
    let data = [
      ("email": "test@example.com"),
      ("password", "123admin"),
      ("remember", "on")
    ]
    bag data:
      email: tEmail or "Invalid email address"
      password: tPassword or "Invalid password"
      *remember: tCheckbox  # optional field, default: off/false
    do:
      # a runnable block of code in case validation fails
      # `return` may be required to block code execution
      echo "oups!"
      return
    echo "ok"

  expectKind rules, nnkStmtList
  result = newStmtList()
  let varBagInstance = newVarStmt(
    ident "inputBag",
    newCall(ident "InputBag")
  )
  var rulesList = newStmtList()
  for r in rules:
    if r.kind == nnkCall:
      # handle required fields
      let node = parseRule(r)
      rulesList.add(
        newCall(
          ident "addRule",
          ident "inputBag",
          node
        )
      )
    elif r.kind == nnkPrefix:
      # handle optional fields
      discard

  result.add varBagInstance
  result.add rulesList
  result.add quote do:
    inputBag.validate(`data`)
  if bodyFail != nil:
    result.add quote do:
      if inputBag.isInvalid:
        `bodyFail`