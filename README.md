# Dashboard in ELM

The goal of this project is to create an easy to configure dashboard.
You will configure the dashboard through the backend and the frontend
will adapt.

The frontend is made in `ELM` and the backend in `Python3` using
`aiohttp`.

## Features

* Show a list of dashboards, allow to pick one.
* Update the frontend in realtime whenever an update is done to the
  dashboard list.
* Show a stub dashboard when one is selected.

## TODO

* Make the backend return the frontend to GET HTTP requests on the root
  route.
* Make the backend and frontend run on same port.
* Add Jenkins build backend.
* Add composable graph elements.
* Add builds graph element representing job builds.
* Make it pretty with some styling.

## Quick Start

In one terminal, run:
```
make frontend-debug
```

In another, run:
```
make BACKEND_ARGS='--dashboard-dir=example_dashboards' backend-debug
```

Then go to `http://localhost:8000/Main.elm`.

Now create the `example_dashboards` directory and fill it with `.py`
files, you'll see the list of dashboards update in realtime in the
frontend app.
