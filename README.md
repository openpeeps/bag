<p align="center">
  <img src="https://github.com/openpeeps/bag/blob/main/.github/logo.png" width="64px"><br>
  Validate HTTP input data in a fancy way.<br>👑 Written in Nim language
</p>

<p align="center">
  <code>nimble install bag</code>
</p>

<p align="center">
  <a href="https://openpeeps.github.io/bag">API reference</a><br>
  <img src="https://github.com/openpeeps/bag/workflows/test/badge.svg" alt="Github Actions"> | <img src="https://github.com/openpeep/bag/workflows/docs/badge.svg" alt="Github Actions">
</p>

## 😍 Key Features
- [x] Macro-based webform validation
- [x] Framework agnostic
- [x] i18n support
- [x] Based on [Valido package](https://github.com/openpeeps/valido)
- [x] Open Source | `MIT` License
- [x] Written in 👑 Nim language

## Examples

```nim
let data = @[
  ("email", "test@example.com"),
  ("password", "abc"),
  ("message", "Hello world")
]

withBag data:
  email: tEmail"auth.error.email"
  password: tPasswordStrength"weak.password"
  message: tTextarea"msg.empty":
    min: 10 or "msg.too.short"
    max: 500 or "msg.too.long"
  *remember: tCheckbox       # optional, default false
  csrf -> callback do(input: string) -> bool:
    result = validateToken("/auth/login", input)
do:
  if inputBag.isInvalid:
    for (field, err) in inputBag.getErrors:
      echo field, ": ", i18n(err)
```

See the [full test suite](https://github.com/openpeeps/bag/blob/main/tests/test1.nim) for all 30+ supported field types.

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeeps/bag/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeeps/bag/fork)

### 🎩 License
Bag | MIT license. [Made by Humans from OpenPeeps](https://github.com/openpeeps).<br>
Copyright &copy; OpenPeeps & Contributors &mdash; All rights reserved.
