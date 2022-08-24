# 0.0.11

* Require `trailblazer-activity-dsl-linear` >= 1.0.0.
* Use `#terminus` instead of clumsily adding termini to `Protocol` and `Adapter`.

# 0.0.10

* Require `dsl-linear` >= 0.5.0.

# 0.0.9

* Fix Ruby 3.0 code.
* Update dependencies.

# 0.0.8

* Add `Protocol.insert_copy_from_domain_ctx!` to copy from `domain_ctx` to the `endpoint_ctx`.

# 0.0.7

* BREAKING: Remove `:domain_ctx_filter` in favor of `Controller.insert_copy_to_domain_ctx!`.
* Add support for serializing `:suspend_data` and deserializing `:resume_data` so session data can get automatically encrypted and passed to the next action. This used to sit in `workflow`.
* Add `:find_process_model`. This introduces a new protocol step before `policy` to find the "process model" instead of letting the domain operation or even the policy (or both!) find the "current model".

# 0.0.6

* `Controller::endpoint` short form introduced.
* Minor changes for `Controller.module`.
* Lots of cleanups.

# 0.0.5

* Removed `Protocol::Failure`. Until we have `Railway::End::Failure`, use a normal `Activity::End` everywhere instead of introducing our own.
* Default `with_or_etc:invoke` is `TaskWrap.invoke`.

# 0.0.4

* Use new `context-0.3.1`.
* Don't use `wtf?`.
* Don't create a `Context` anymore in `Endpoint.arguments_for`.

# 0.0.3

* Introduce `Options`.
* Introduce `Controller::DSL`.

# 0.0.2

The `:collaboration` and `:dictionary` options for `arguments_for` are now optional and figured out by `workflow`.

# 0.0.1

* Provides very simple `Protocol` implementations for `Web` and `API`, same for `Adapter`.
