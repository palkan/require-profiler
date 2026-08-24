# Change log

## master

- Update the skill: cover the Rails initialization, prefixes and refresh the boot-optimization guidance. ([@ardecvz][])

## 0.3.1 (2026-08-14)

- Rename hyperdrive gemspec metadata keys to a new `rails_hyperdrive_*` contract, so the skill is discoverable again. ([@ardecvz][])

## 0.3.0 (2026-07-23)

- Add Rails initialization tracking: railtie initializers, `to_prepare` callbacks, and lazy load hooks. ([@ardecvz][])

- Prefix HTTP nodes with `http:`. ([@ardecvz][])

## 0.2.3 (2026-06-05)

- Add SKILL.md for rails-hyperdrive. ([@palkan][])

## 0.2.2 (2026-06-05)

- Fixed YAML tracking when Pathname is used. ([@palkan][])

## 0.2.1 (2026-05-26)

- Add YAML tracking. ([@palkan][])

- Add HTTP tracking via Sniffer. ([@palkan][])

## 0.2.0 (2026-05-25) 🔔

- Add ability to run Stackprof for a particular file loading. ([@palkan][])

- Add focus support (to include only matching files). ([@palkan][])

- Add threshold support (`REQUIRE_PROFILE_THRESHOLD`). ([@palkan][])

- Add `-require-prof` support. ([@palkan][])

- Support passing format and output path via `REQUIRE_PROFILE_FORMAT` and `REQUIRE_PROFILE_PATH`. ([@palkan][])

## 0.1.1 (2026-04-29)

- Fix JSON printer leaving trailing call-stack bytes in output. ([@ardecvz][])

We overwrite the buffered call-stack text with a (shorter) Speedscope JSON document but never truncate it, breaking JSON validity.

Truncate the file properly.

## 0.1.0 (2026-04-22)

- Initial

[@palkan]: https://github.com/palkan
[@ardecvz]: https://github.com/ardecvz
