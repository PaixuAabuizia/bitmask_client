GITC = `git rev-parse --short HEAD`
DMG = "dist/leap-client-$(GITC).exe"
INST = "dist/LEAP Client installer.exe"

.PHONY: all pkg installer dependencies
all:
	# clean: ~40m (3mbit)
	# noclean: ~3s
	# winhq may do 503 sometimes
	docker-compose build
	$(MAKE) pkg

# ~3min
pkg:
	$(MAKE) dependencies
	$(MAKE) installer

dependencies:
	docker-compose run --rm dependencies

installer:
	docker-compose run --rm installer

clean:
	docker rmi windows_dependencies
	docker rmi windows_installer
	rm -rf ../../dist/*.exe