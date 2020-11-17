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
