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
* Useful for debugging, the `make frontend-debug` reloads the page on
  code change.
* The backend serves the frontend on the `/` route. The backend and
  frontend thus run on the same port.
* The frontend Elm code is embedded in a small HTML file. This allows
  using CSS sheets.
* CSS stylesheet is generated with elm-css. It also reloads on code change.

## TODO

* Add Jenkins build backend.
* Add composable graph elements.
* Add builds graph element representing job builds.
* Make it pretty with some styling [in progress].

## Quick Start

Run:
```
make BACKEND_ARGS='--dashboard-dir=example_dashboards' app-run
```

This will start the backend, listening on <http://localhost:8080>.

Now create the `example_dashboards` directory and fill it with `.py`
files, you'll see the list of dashboards update in realtime in the
frontend app.


## Debug frontend

In one terminal, run:
```
make frontend-debug
```

In another, run:
```
make BACKEND_ARGS='--dashboard-dir=example_dashboards' backend-debug
```

Then go to <http://localhost:8000/Main.elm>.

Note that the webpage (frontend) code reloads automatically while the
python (backend) code doesn't yet.

Note also that, for now, the `backend-debug` is equivalent to `app-run`
Makefile target.
