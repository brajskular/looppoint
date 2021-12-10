UBUNTU_VERSION?=18.04
TOOL?=looppoint
#SNIPER_GIT_REPO?="http://snipersim.org/download/6abd19013a9e7ae0/git/sniper.git"
DOCKER_IMAGE?=ubuntu:$(UBUNTU_VERSION)-$(TOOL)
DOCKER_FILE?=Dockerfile-ubuntu-$(UBUNTU_VERSION)
DOCKER_FILES=$(wildcard Dockerfile*)
# For use with --no-cache, etc.
DOCKER_BUILD_OPT?=
# Reconstruct the timezone for tzdata
TZFULL=$(subst /, ,$(shell readlink /etc/localtime))
TZ=$(word $(shell expr $(words $(TZFULL)) - 1 ),$(TZFULL))/$(word $(words $(TZFULL)),$(TZFULL))

run:
	docker run --rm -it -v "${PWD}:${PWD}" --user $(shell id -u):$(shell id -g) -w "${PWD}" $(DOCKER_IMAGE)

run-root-cwd:
	docker run --privileged --rm -it -v "${PWD}:${PWD}" --user root -w "${PWD}" $(DOCKER_IMAGE)

run-root:
	docker run --rm -it -v "${HOME}:${HOME}" $(DOCKER_IMAGE)

apps:
	make -C apps/demo/matrix-omp

pinkit:
	@if [ ! -d "tools/pin-3.13-98189-g60a6ef199-gcc-linux" ]; then \
		$(info Downloading Pin) \
		wget -O - https://software.intel.com/sites/landingpage/pintool/downloads/pin-3.13-98189-g60a6ef199-gcc-linux.tar.gz  --no-check-certificate | tar -xf - -z -C tools/ ; \
		cp -r tools/pinplay tools/pin-3.13-98189-g60a6ef199-gcc-linux/extras/ ; \
		patch -d tools -p 0 -i pin_alarms.patch ; \
	fi

sniper: pinkit
ifndef SNIPER_GIT_REPO
	$(error Please set the SNIPER_GIT_REPO variable to the Sniper link. If you do not have one, visit https://snipersim.org/w/Download)
endif
	@if [ ! -d "tools/sniper" ]; then \
		$(info Setting SNIPER_GIT_REPO as $(SNIPER_GIT_REPO) to download Sniper) \
		git clone $(SNIPER_GIT_REPO) tools/sniper && \
		mkdir -p tools/sniper/pin_kit && \
		cp -r tools/pin-3.13-98189-g60a6ef199-gcc-linux/* tools/sniper/pin_kit && \
		patch -d tools -p 0 -i sniper_looppoint.patch && \
		make -C tools/sniper -j ; \
	fi

tools: sniper

build: $(DOCKER_FILE).build

# Use a .PHONY target to build all of the docker images if requested
Dockerfile%.build: Dockerfile%
	docker build --build-arg TZ_ARG=$(TZ) $(DOCKER_BUILD_OPT) -f $(<) -t ubuntu:$(subst Dockerfile-ubuntu-,,$(<))-$(TOOL) .

BUILD_ALL_TARGETS=$(foreach f,$(DOCKER_FILES),$(f).build)
build-all: $(BUILD_ALL_TARGETS)

clean:
	rm -f *.pyc *.info.log  *.log 
	make -C apps/demo/matrix-omp clean

distclean:
	rm -rf tools/pin-3.13-98189-g60a6ef199-gcc-linux tools/sniper results/

.PHONY: build build-all run-root run run-cwd apps pinkit tools clean distclean