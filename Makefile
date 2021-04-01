build:
	docker build -t setup-workstation .

run:
	docker run -ti --rm setup-workstation /bin/sh -c "/setup_workstation.sh"
