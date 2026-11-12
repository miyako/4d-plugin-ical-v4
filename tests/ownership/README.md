# Ownership regressions

ASan/UBSan harness for the plugin's 4D string, variable, picture and object
ownership. It compiles the real `4DPlugin-iCal.cpp` (unity-included by
`harness.mm`), `support/4DPlugin-JSON.cpp`, `C_TEXT.cpp` and the bundled SDK
`4DPluginAPI.c`, and runs them against `fake_engine.cpp`, a synthetic 4D engine
installed as `gCall4D`. EventKit stores and events are fake objects; no calendar
data is read. Leaks are counted by the engine (LSan is unavailable on macOS).

    tests/ownership/run.sh [SOURCE_ROOT] [expected-failure ...]

`SOURCE_ROOT` defaults to this checkout. To run the same harness against an
older tree, extract it (for example with `git archive <sha> | tar -x -C dir`)
and pass that directory with the names of the tests expected to fail there.

Test prefixes: `live_` (reachable from plugin commands), `dormant_` (helpers
with no caller), `hardening_` (not proven to occur in 4D) and `control_`
(must pass before and after a fix).
