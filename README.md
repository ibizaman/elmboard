# Dashboard in ELM

The goal of this project is to create an easy to configure dashboard.
You will configure the dashboard through the backend and the frontend
will adapt.

The frontend is made in `ELM` and the backend in `Python3` using
`aiohttp`.

## Features

* Show a list of dashboards, allow to pick one.
* Show a stub dashboard when one is selected.

## TODO

* Make the backend return the frontend to GET http requests on the root
  route.
* Make the backend and frontend run on same port.
* Return the actual list of dashboards.
* Add jenkins build backend.
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
make backend-debug
```

Then go to `http://localhost:8000/Main.elm`.
