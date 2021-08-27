IMAGE_NAME := asdf-env

shell: contrib/Dockerfile
	docker build -t $(IMAGE_NAME) -f $< .
	docker run --rm -v $(PWD):/root/.asdf/plugins/go-sdk -it $(IMAGE_NAME) bash

lint:
	shfmt -f .
	scripts/shfmt.bash

	go fmt ./...
	go vet ./...
