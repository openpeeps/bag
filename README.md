<p align="center">
  <img src="https://github.com/openpeep/bag/blob/main/.github/logo.png" width="90px"><br>
  Validate HTTP input data in a fancy way.<br>projects and other cool things. 👑 Written in Nim language
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
- [x] Based on [Valido package](https://github.com/openpeep/valido)
- [x] Open Source | `MIT` License
- [x] Written in 👑 Nim language

## Examples

The macro way
```nim
var fields = [("email", "test@example.com"), ("password", "123admin")]
newBag fields:
  email: TEmail
  password: TPassword or "auth.error.password":
    min: 30 or "auth.error.password.min"
    max: 40
  message: TTextarea
  *remember: TCheckbox  # Optional field
```

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](/issues)
- 👋 Wanna help? [Fork it!](/fork)
- 😎 [Get €20 in cloud credits from Hetzner](https://hetzner.cloud/?ref=Hm0mYGM9NxZ4)
- 🥰 [Donate via PayPal address](https://www.paypal.com/donate/?hosted_button_id=RJK3ZTDWPL55C)

### 🎩 License
Bag | MIT license. [Made by Humans from OpenPeep](https://github.com/openpeep).<br>
Copyright &copy; 2023 OpenPeep & Contributors &mdash; All rights reserved.
