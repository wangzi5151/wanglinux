# WangLinux 构建入口 —— make <target>
# 用法同 ./build.sh（二者等价），支持 ARCH= / FLAVOR= / OUT= 等变量透传

.PHONY: help iso qcow2 rootfs container wsl arm64-image pi deb repo all

help:
	@./build.sh help

iso:
	./build.sh iso

qcow2:
	./build.sh qcow2

rootfs:
	./build.sh rootfs

container:
	./build.sh container

wsl:
	./build.sh wsl

arm64-image:
	./build.sh arm64-image

pi:
	./build.sh pi

deb:
	./build.sh deb

repo:
	./build.sh repo

all:
	./build.sh all
