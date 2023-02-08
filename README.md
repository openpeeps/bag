<p align="center">
  <img src="https://github.com/openpeep/bag/blob/main/.github/logo.png" width="64px"><br>
  Validate HTTP input data in a fancy way.<br>👑 Written in Nim language
</p>

<p align="center">
  <code>nimble install bag</code>
</p>

<p align="center">
  <a href="https://openpeep.github.io/bag">API reference</a><br>
  <img src="https://github.com/openpeep/bag/workflows/test/badge.svg" alt="Github Actions"> | <img src="https://github.com/openpeep/bag/workflows/docs/badge.svg" alt="Github Actions">
</p>

## 😍 Key Features
- [x] Macro-based validation
- [x] Framework agnostic
- [x] i18n support
- [x] Based on [Valido package](https://github.com/openpeep/valido)
- [x] Open Source | `MIT` License
- [x] Written in 👑 Nim language

## Examples

The macro way
```nim
# can be a seq/array containing a key/value tuple (string, string)
var data = [("email", "test@example.com"), ("password", "123admin")]

# create a new bag with given data
newBag data:
  email: TEmail or "auth.error.email"
  password: TPassword or "auth.error.password":
    min: 8 or "auth.error.password.min"
  *remember: TCheckbox  # Optional field. Default: false

if Bag.isInvalid:
  for err in Bag.getErrors:
    echo err
```

For more examples, check in [unittests](https://github.com/openpeep/bag/blob/main/tests/test1.nim)

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeep/bag/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeep/bag/fork)
- 😎 [Get €20 in cloud credits from Hetzner](https://hetzner.cloud/?ref=Hm0mYGM9NxZ4)
- 🥰 [Donate via PayPal address](https://www.paypal.com/donate/?hosted_button_id=RJK3ZTDWPL55C)

### 🎩 License
Bag | MIT license. [Made by Humans from OpenPeep](https://github.com/openpeep).<br>
Copyright &copy; 2023 OpenPeep & Contributors &mdash; All rights reserved.
