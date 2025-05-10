# build - this will take about 1h
podman build --build-arg FEDORA_VER=41 -t rocm-dev:41 -f dockerfiles/pytorch-dev/rocm_fedora.Dockerfile .

# tag it for the next step
podman tag localhost/rocm-dev:41 rocm-dev-f41:latest
