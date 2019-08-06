# Trailblazer::Endpoint

*Generic HTTP handlers for operation results.*

Decouple finding out *what happened* from *what to do*.

## Motivation

Trailblazer brings a lot of clarity to your controller logic,
pushing you to create operations that have a clear workflow. Each operation
returns a result object with enough information in it to evaluate what to do.
The problem now lies on the code duplication that one is forced to write to
evaluate a set of possible cases, generally solved the same way for each
controller.

E.g. an unauthenticated request should always be resolved in the same way
(exclude special cases)

From this idea, Endpoint gem came to life. Wrapping some of the most common
cases with a common solution for them. This allows you to don't have to worry
with the returning values of each of your operations.

Naturally, not everyone has common cases and, in the light of Trailblazer
flexibility, you can override all the behavior at any level of the app.

## Usage

### If your operation does not have a representer specified

Consider the following controller

```ruby
class Api::V1::MyMagicController < Api::V1::BaseController
  def index
    result = V1::MyMagic::Index.(params, current_user: current_user)
    response = Trailblazer::Endpoint.(result, V1::MyMagic::Representer::Index)
    render json: response[:data], status: response[:status]
  end
end
```

As you can see, the controller calls your operation that will return a result
object. This object is then passed to `Trailblazer::Endpoint` that will inspect
the result object and decide what to put in the response. Typically, response
object will have a param `data` and a `status`.

E.g. if the operation is `successful`, then `data` will have the representation
of the `model` while `status` will have `:ok`.

### If your operation has a representer specified

Consider the following controller

```ruby
class Api::V1::MyMagicController < Api::V1::BaseController
  def index
    result = V1::MyMagic::Index.(params, current_user: current_user)
    response = Trailblazer::Endpoint.(result)
    render json: response[:data], status: response[:status]
  end
end
```

The main difference is that Endpoint during the inspection will fetch
the representer class automatically. This way you don't need to pass a
representer to the Endpoint. All the remaining logic is still valid.

## How to override the default matchers?

As promised in the motivation, if you feel the need to override a specific
matcher, you can do so both globally (good for when your whole application
needs this logic) or locally (good if a specific endpoint is expected to behave
differently).


Consider the following controller

```ruby
class Api::V1::MyMagicController < Api::V1::BaseController
  def index
    op_res = V1::MyMagic::Index.(params, current_user: current_user)
    success_proc = ->(result, _representer) do
      { "data": result["response"], "status": :ok }
    end
    response = Trailblazer::Endpoint.(op_res, nil, success: { resolve: success_proc })
    render json: response[:data], status: response[:status]
  end
end
```

In this particular case, the default behavior for a successful operation is not
what we want to use. So we can write our own resolution and pass it as part
of the overrides. Because we pass it to the endpoint as the `resolve` proc for
the matcher `success`, the existing `success` rule will still be evaluated and
in case it returns true, our `success_proc` will be invoked instead.

Likewise we can override the matching logic.

Consider the following controller

```ruby
class Api::V1::MyMagicController < Api::V1::BaseController
  def index
    op_res = V1::MyMagic::Index.(params, current_user: current_user)
    success_proc = ->(result) { result.success? && result['models'].count > 0 }
    response = Trailblazer::Endpoint.(op_res, nil, success: { rule: success_proc })
    render json: response[:data], status: response[:status]
  end
end
```

You can easily understand that we are now overriding the rule proc with one of
our custom made rules. The resolution would still be the default one.

## Completely custom solution

As you can imagine we can't think of all possible solutions for every single
use case. So this gem still gives you the flexibility of creating your own
matchers and resolutions. Any custom matcher will be evaluated before the
default ones. If you provide a custom matcher with an existing name, you'll be
overriding the whole matcher with your own solution.

Consider the following controller

```ruby
class Api::V1::MyMagicController < Api::V1::BaseController
  def index
    op_res = V1::MyMagic::Index.(params, current_user: current_user)
    success = { success: {
        rule: ->(result) { result.success? && result['models'].count > 0 },
        resolve: ->(result, _representer) { { data: "more than 0", status: :ok } }
      }
    }
    super_special = {
      super_special: {
        rule: ->(result) { result.success? && result['models'].count > 100 },
        resolve: ->(result, _representer) { { data: "more than 100", status: :ok } }
      }
    }
    response = Trailblazer::Endpoint.(op_res, nil, { super_special: super_special, success: success } )
    render json: response[:data], status: response[:status]
  end
end
```

In this more complex example, we are creating a custom `super_special` matcher
and overriding the `success`. Please note that the order is important and as
mentioned before, custom matchers will be evaluated before the default ones.
This applies for the overridden ones as well.

t test/controllers/songs_controller_test.rb --backtrace

## TODO

* make travis build run `cd test/rails-app/ && rake`
