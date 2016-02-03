GITC = `git rev-parse --short HEAD`
DMG = "dist/leap-client-$(GITC).exe"
INST = "dist/LEAP Client installer.exe"

.PHONY: all pkg installer dependencies
all:
	# clean: ~40m (3mbit)
	# noclean: ~3s
	# winehq may do 503 sometimes
	docker-compose build
	$(MAKE) pkg

# ~3min
pkg:
	$(MAKE) pyinstaller
	$(MAKE) openvpn
	$(MAKE) installer

pyinstaller:
	docker-compose run --rm pyinstaller

openvpn:
	docker-compose run --rm openvpn

installer:
	docker-compose run --rm installer

clean:
	docker rmi windows_pyinstaller
	docker rmi windows_openvpn
	docker rmi windows_installer
	rm -rf ../../dist/*.exe