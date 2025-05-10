# https://github.com/scottt/rocm-TheRock/blob/gfx1151/dockerfiles/pytorch-dev/pytorch_dev_fedora.Dockerfile

ARG FEDORA_VER=41
FROM rocm-dev-f${FEDORA_VER} AS build

ENV AMDGPU_TARGETS=gfx1151
ENV AOTRITON_BUILD_FROM_SOURCE=1

# pytorch-fetch
RUN --mount=type=cache,id=pytorch-f${FEDORA_VER},target=/therock \
	mkdir -p /therock/pytorch

RUN --mount=type=cache,id=pytorch-f${FEDORA_VER},target=/therock \
	--mount=type=bind,target=/therock/src,rw \
	python3 /therock/src/external-builds/pytorch/ptbuild.py \
		checkout \
                --pytorch-ref v2.7.0 \
		--repo /therock/pytorch \
		--depth 1 \
		--jobs 10 \
		--no-patch \
		--no-hipify

# pytorch-prep
# for `git am`
RUN git config --global user.email "you@example.com" && \
    git config --global user.name "Your Name"

RUN --mount=type=cache,id=pytorch-f${FEDORA_VER},target=/therock \
	--mount=type=bind,target=/therock/src,rw \
	python3 /therock/src/external-builds/pytorch/ptbuild.py \
		checkout \
                --pytorch-ref v2.7.0 \
		--repo /therock/pytorch  \
		--depth 1  \
		--jobs 10

# pytorch-build
RUN --mount=type=cache,id=pytorch-f${FEDORA_VER},target=/therock \
	cd /therock/pytorch && \
	uv pip install --system -r requirements.txt

ENV CMAKE_PREFIX_PATH=/opt/rocm
ENV USE_KINETO=OFF
ENV USE_FBGEMM=0
ENV PYTORCH_ROCM_ARCH=$AMDGPU_TARGETS
ENV USE_ROCM_CK=0
ENV CMAKE_CXX_FLAGS_POST="-Wno-error"
# Doesn't work?
ENV NO_WERROR=1
ENV CMAKE_ARGS="-DUSE_ROCTX=OFF \
                -DPYTORCH_ROCM_ARCH=${AMDGPU_TARGETS} \
                -DFBGEMM_WERROR=OFF \
                -DUSE_ROCM_CK_GEMM=OFF \
                -DCMAKE_CXX_FLAGS_POST='-Wno-error'"

# fix ROCM_ROCTX_LIB NOTFOUND error
RUN ln -s /opt/rocm/lib/librocprofiler-sdk-roctx.so /opt/rocm/lib/libroctx64.so

RUN --mount=type=cache,id=pytorch-f${FEDORA_VER},target=/therock \
	cd /therock/pytorch && \
	python setup.py build --cmake-only && \
	pushd build && \
        cmake \
          -DPYTORCH_ROCM_ARCH=$AMDGPU_TARGETS \
          -DUSE_ROCTX=OFF \
          -DROCM_ROCTX_LIB=/opt/rocm/lib/librocprofiler-sdk-roctx.so \ 
          . && \
        popd && \
	python setup.py bdist_wheel

RUN --mount=type=cache,id=pytorch-f${FEDORA_VER},target=/therock \
	rm -f /opt/torch-*.whl && \
	cp $(ls -t /therock/pytorch/dist/torch-*.whl | head -n 1) /opt

# Development image
FROM rocm-dev-f${FEDORA_VER} AS pytorch-dev-f${FEDORA_VER}
COPY --from=build /opt/torch-*.whl /opt
RUN uv pip install --system /opt/*.whl

# the setuptools from rocm-dev-f${FEDORA_VER} could be too new
# and cause C++ extensions of pytorch, like pytorch-vision to fail to build
RUN uv pip install --system 'setuptools>=62.3.0,<75.9'
