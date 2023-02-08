# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "Validate HTTP input data in a fancy way"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.6.10"
requires "valido >= 0.1.0"

task dev, "dev":
  echo "\n✨ Compiling..." & "\n"
  exec "nim c --gc:arc --path:. --out:bin/valido src/valido.nim"