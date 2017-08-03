BACKEND_ARGS=


install-archlinux:  ## Install every dependency not installable through pip, on an archlinux system.
	hash npm 2>/dev/null || sudo pacman -S npm
	hash elm 2>/dev/null || sudo npm install -g elm elm-test elm-oracle elm-format
	hash virtualenv 2>/dev/null || sudo pip install -U virtualenv


venv: venv/bin/activate  ## Setup a virtual environment with all pip installable dependencies.
venv/bin/activate: requirements.txt setup.py
	test -d venv || virtualenv venv
	venv/bin/pip install -e .[dev,test]
	touch venv/bin/activate


backend-debug: venv  ## Start the server in debug mode.
	venv/bin/python backend-py3/server.py $(BACKEND_ARGS)


frontend-make:  ## Compile the frontend code.
	cd frontend \
	    && elm-package install elm-lang/websocket \
	    && elm-make Main.elm \


frontend-debug:  ## Start the elm-reactor server.
	cd frontend; elm-reactor


help:  ## This help
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	    | sort \
	    | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
