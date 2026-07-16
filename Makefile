name ?= payments-test-client

build-container:
	docker build -t $(name) .

run-container:
	@echo Hosting to http://localhost:3331
	@docker run --rm --pull=never --name $(name) --publish=127.0.0.1:3331:3331 $(name)
