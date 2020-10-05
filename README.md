# Trailblazer::Endpoint

*Endpoints handle authentication, authorization, calling the business logic and response rendering.*

## Overview

An endpoint links your routing with your business code. The idea is that your controllers are pure HTTP routers, calling the respective endpoint for each action. From there, the endpoint takes over, handles authentication, policies, executing the domain code, interpreting the result, and providing hooks to render a response.

Instead of dealing with a mix of `before_filter`s, Rack-middlewares, controller code and callbacks, an endpoint is just another activity and allows to be customized with the well-established Trailblazer mechanics.


In a Rails controller, a controller action could look as follows.

```ruby
class DiagramsController < ApplicationController
  endpoint Diagram::Operation::Create, [:is_logged_in?, :can_add_diagram?]

  def create
    endpoint Diagram::Operation::Create do |ctx|
      redirect_to diagram_path(ctx[:diagram].id)
    end.Or do |ctx|
      render :form
    end
  end
end
```

While routing and redirecting/rendering still happens in Rails, all remaining steps are handled in the endpoint.

An API controller action, where the rendering is done generically, could look much simpler.

```ruby
class API::V1::DiagramsController < ApplicationController
  endpoint Diagram::Operation::Create, [:is_logged_in?, :can_add_diagram?]

  def create
    endpoint Diagram::Operation::Create
  end
end
```

Endpoints are easily customized but their main intent is to reduce fuzzy controller code and providing best practices for both HTML-rendering controllers and APIs.

## Documentation

Read the [full documentation for endpoint](https://trailblazer.to/2.1/docs/endpoint.html) on our website.
