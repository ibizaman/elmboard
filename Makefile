.PHONY:\
    app-run\
    backend-debug\
    frontend-debug\
    frontend-make\
    frontend-make-css\
    frontend-test\
    help\
    install-archlinux\

BACKEND_ARGS=


install-archlinux:  ## Install every dependency not installable through pip, on an archlinux system.
	hash npm 2>/dev/null || sudo pacman -S npm
	hash elm 2>/dev/null || sudo npm install -g elm
	hash elm-test 2>/dev/null || sudo npm install -g elm-test
	hash elm-oracle 2>/dev/null || sudo npm install -g elm-oracle
	hash elm-format 2>/dev/null || sudo npm install -g elm-format
	hash elm-live 2>/dev/null || sudo npm install -g elm-live
	hash elm-css 2>/dev/null || sudo npm install -g elm-css
	hash virtualenv 2>/dev/null || sudo pip install -U virtualenv


venv: venv/bin/activate  ## Setup a virtual environment with all pip installable dependencies.
venv/bin/activate: requirements.txt setup.py
	test -d venv || virtualenv venv
	venv/bin/pip install -e .[dev,test]
	touch venv/bin/activate


backend-debug: venv  ## Start the server in debug mode.
	venv/bin/python backend-py3/server.py $(BACKEND_ARGS)


frontend-make-css: frontend/StylesheetGenerator.elm frontend/MyCss.elm
	cd frontend && \
	    elm-css --output static StylesheetGenerator.elm


frontend-test:
	cd frontend && \
	    elm-test


frontend-make: frontend-test frontend-make-css  ## Compile the frontend code.
	cd frontend \
	    && elm-package install elm-lang/websocket \
	    && elm-make Main.elm \


frontend-debug:  ## Start the elm-live server.
	# elm-live expected index.html to be inside the frontend folder
	cd frontend\
	    && elm-live \
	    	--before-build=./beforeElmLive.sh \
		--output=static/Main.js \
		Main.elm \
		

app-run: venv frontend-make-css  ## Start the app in prod mode.
	venv/bin/python backend-py3/server.py $(BACKEND_ARGS)


help:  ## This help
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	    | sort \
	    | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
