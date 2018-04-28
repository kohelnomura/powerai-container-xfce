FROM nvidia/cuda-ppc64le:9.1-cudnn7-devel-ubuntu16.04
MAINTAINER kohhei Nomura <kohei1@jp.ibm.com>

# install base
RUN apt-get update && \
    apt-get install -y wget curl git apt-transport-https apt-utils && \
    apt-get clean

# install utils
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    vim htop tree screen zip unzip  \
    openssh-server \
    ubuntu-desktop gnome-core gdm gnome-panel gnome-settings-daemon metacity nautilus gnome-terminal \
    iputils-ping net-tools \
    language-pack-ja-base language-pack-ja fonts-ipafont-mincho build-essential openjdk-8-jdk && \
    apt-get clean

# install python3 module
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python python3 python3-pip python3-numpy python3-scipy python3-matplotlib python3-dev python3-wheel && \
    apt-get clean

# upgrade module
RUN DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
    apt-get clean

# setup python3
RUN update-alternatives --install /usr/bin/python python /usr/bin/python2 10
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 11

# nuild Bazel 0.10.0 for Tensorflow v1.6.0
RUN cd /tmp && \
    mkdir bazel && \
    cd bazel && \
    wget https://github.com/bazelbuild/bazel/releases/download/0.10.0/bazel-0.10.0-dist.zip && \
    unzip bazel-0.10.0-dist.zip && \
    chmod -R +w .&& \
    ./compile.sh 

ENV PATH=$PATH:/tmp/bazel/output/
ENV LD_LIBRARY_PATH /usr/local/cuda/extras/CUPTI/lib64:$LD_LIBRARY_PATH

RUN cd /tmp && \
    git clone --recurse-submodules https://github.com/tensorflow/tensorflow && \
    cd tensorflow && \ 
    git checkout v1.6.0 && \
    export CC_OPT_FLAGS="-mcpu=power8 -mtune=power8" && \
    export GCC_HOST_COMPILER_PATH=/usr/bin/gcc && \
    export PYTHON_BIN_PATH=/usr/bin/python && \
    export USE_DEFAULT_PYTHON_LIB_PATH=1 && \
    export TF_NEED_GCP=1 && \
    export TF_NEED_HDFS=1 && \
    export TF_NEED_JEMALLOC=1 && \
    export TF_ENABLE_XLA=0 && \
    export TF_NEED_OPENCL=0 && \
    export TF_NEED_CUDA=1 && \
    export TF_CUDA_VERSION=9.1 && \
    export CUDA_TOOLKIT_PATH=/usr/local/cuda-9.1 && \
    export TF_CUDA_COMPUTE_CAPABILITIES=3.5,5.2 && \
    export CUDNN_INSTALL_PATH=/usr/local/cuda-9.1 && \
    export TF_CUDNN_VERSION=7 && \
    export TF_NEED_MKL=0 && \
    export TF_NEED_VERBS=0 && \
    export TF_NEED_MPI=0 && \
    export TF_CUDA_CLANG=0 && \
    export TF_NEED_S3=1 && \
    export TF_NEED_OPENCL_SYCL=0 && \
    export TF_NEED_GDR=0 && \
    export TF_SET_ANDROID_WORKSPACE=0 && \
    ./configure && \
    touch /usr/include/stropts.h && \
    ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1 && \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64/stubs:${LD_LIBRARY_PATH} \
    tensorflow/tools/ci_build/builds/configured GPU \
    bazel build --copt="-mcpu=power8" --copt="-mtune=power8" --config=cuda //tensorflow/tools/pip_package:build_pip_package --verbose_failures --local_resources=32000,8,1.0 && \
    bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg && \
    pip3 install /tmp/tensorflow_pkg/tensorflow-1.6.0*

# Build nccl ver1
RUN cd / && \
    git clone https://github.com/NVIDIA/nccl.git && \
    cd /nccl  && \
    make CUDA_HOME=/usr/local/cuda-9.1 test 

ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/nccl/build/lib

# delete tf directories
RUN rm -rf /tmp/tensorflow /tmp/bazel /tmp/tensorflow_pkg /root/.cache /var/lib/apt/lists/*

# install vncserver
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    x11vnc xfce4 xvfb fonts-ipaexfont && \
    apt-get clean

# copy base files
COPY root /
COPY password.txt .

# setup ssh
RUN mkdir /var/run/sshd
RUN echo root:$(cat password.txt) | chpasswd
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i '/^AcceptEnv/s/^/#/' /etc/ssh/sshd_config
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
RUN echo "export PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH" >> /root/.bashrc && \
    echo "export LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64" >> /root/.bashrc

# setup vnc
RUN  x11vnc -storepasswd $(cat password.txt) /root/.vnc/passwd && rm password.txt

# setup timezone and locale
ENV TZ=Asia/Tokyo
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN echo "export LANG=ja_JP.UTF-8" >> /root/.bashrc
RUN echo "export LANGUAGE=ja_JP.UTF-8" >> /root/.bashrc
ENV LANGUAGE=ja_JP
ENV LANG=ja_JP.UTF-8

# install dl utilities
#RUN pip3 install IPython
RUN pip3 install jupyter
RUN mkdir /root/.jupyter
RUN echo "c.NotebookApp.ip = '*'" > ~/.jupyter/jupyter_notebook_config.py
RUN pip3 install keras==2.0.5
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y graphviz libhdf5-dev && \
    apt-get clean && \
    pip3 install h5py

# install opencv
RUN cd / && \
    wget https://cmake.org/files/v3.6/cmake-3.6.2.tar.gz && \
    tar xvf cmake-3.6.2.tar.gz  && \
    cd cmake-3.6.2 && \
    ./bootstrap && make && make install
RUN cd / && \
    git clone https://github.com/opencv/opencv.git && \
    cd opencv && \
    git checkout 3.4.0 && \
    mkdir build
RUN cd /opencv/build && cmake \
    -D CMAKE_INSTALL_PREFIX=/usr/local/opencv3.4 \
    -D PYTHON_EXECUTABLE=$(which python) \
    -D PYTHON3_INCLUDE_DIR=$(python -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") \
    -D PYTHON3_LIBRARY=/usr/lib/python3.5/config-3.5m-powerpc64le-linux-gnu \
    -D BUILD_CUDA_STUBS=OFF \
    -D BUILD_DOCS=OFF \
    -D BUILD_EXAMPLES=OFF \
    -D BUILD_JASPER=OFF \
    -D BUILD_JPEG=OFF \
    -D BUILD_OPENEXR=OFF \
    -D BUILD_PACKAGE=ON \
    -D BUILD_PERF_TESTS=OFF \
    -D BUILD_PNG=OFF \
    -D BUILD_SHARED_LIBS=ON \
    -D BUILD_TBB=OFF \
    -D BUILD_TESTS=OFF \
    -D BUILD_TIFF=OFF \
    -D BUILD_WITH_DEBUG_INFO=ON \
    -D BUILD_ZLIB=OFF \
    -D BUILD_WEBP=OFF \
    -D BUILD_opencv_apps=ON \
    -D BUILD_opencv_calib3d=ON \
    -D BUILD_opencv_core=ON \
    -D BUILD_opencv_cudaarithm=OFF \
    -D BUILD_opencv_cudabgsegm=OFF \
    -D BUILD_opencv_cudacodec=OFF \
    -D BUILD_opencv_cudafeatures2d=OFF \
    -D BUILD_opencv_cudafilters=OFF \
    -D BUILD_opencv_cudaimgproc=OFF \
    -D BUILD_opencv_cudalegacy=OFF \
    -D BUILD_opencv_cudaobjdetect=OFF \
    -D BUILD_opencv_cudaoptflow=OFF \
    -D BUILD_opencv_cudastereo=OFF \
    -D BUILD_opencv_cudawarping=OFF \
    -D BUILD_opencv_cudev=OFF \
    -D BUILD_opencv_features2d=ON \
    -D BUILD_opencv_flann=ON \
    -D BUILD_opencv_highgui=ON \
    -D BUILD_opencv_imgcodecs=ON \
    -D BUILD_opencv_imgproc=ON \
    -D BUILD_opencv_java=OFF \
    -D BUILD_opencv_ml=ON \
    -D BUILD_opencv_objdetect=ON \
    -D BUILD_opencv_photo=ON \
    -D BUILD_opencv_python2=OFF \
    -D BUILD_opencv_python3=ON \
    -D BUILD_NEW_PYTHON_SUPPORT=ON \
    -D BUILD_opencv_python3=ON \
    -D HAVE_opencv_python3=ON \
    -D BUILD_opencv_shape=ON \
    -D BUILD_opencv_stitching=ON \
    -D BUILD_opencv_superres=ON \
    -D BUILD_opencv_ts=ON \
    -D BUILD_opencv_video=ON \
    -D BUILD_opencv_videoio=ON \
    -D BUILD_opencv_videostab=ON \
    -D BUILD_opencv_viz=OFF \
    -D BUILD_opencv_world=OFF \
    -D CMAKE_BUILD_TYPE=RELEASE \
    -D CMAKE_CXX_FLAGS="-mtune=power8" \
    -D CMAKE_C_FLAGS="-mtune=power8" \
    -D WITH_1394=ON \
    -D WITH_CUBLAS=OFF \
    -D WITH_CUDA=OFF \
    -D WITH_CUFFT=OFF \
    -D WITH_EIGEN=ON \
    -D WITH_FFMPEG=ON \
    -D WITH_GDAL=OFF \
    -D WITH_GPHOTO2=OFF \
    -D WITH_GIGEAPI=ON \
    -D WITH_GSTREAMER=ON \
    -D WITH_GTK=ON \
    -D WITH_INTELPERC=OFF \
    -D WITH_IPP=ON \
    -D WITH_IPP_A=OFF \
    -D WITH_JASPER=ON \
    -D WITH_JPEG=ON \
    -D WITH_LIBV4L=ON \
    -D WITH_OPENCL=ON \
    -D WITH_OPENCLAMDBLAS=OFF \
    -D WITH_OPENCLAMDFFT=OFF \
    -D WITH_OPENCL_SVM=OFF \
    -D WITH_OPENEXR=ON \
    -D WITH_OPENGL=ON \
    -D WITH_OPENMP=OFF \
    -D WITH_OPENNI=OFF \
    -D WITH_PNG=ON \
    -D WITH_PTHREADS_PF=OFF \
    -D WITH_PVAPI=ON \
    -D WITH_QT=OFF \
    -D WITH_TBB=ON \
    -D WITH_TIFF=ON \
    -D WITH_UNICAP=OFF \
    -D WITH_V4L=ON \
    -D WITH_VTK=OFF \
    -D WITH_WEBP=ON \
    -D WITH_XIMEA=OFF \
    -D WITH_XINE=OFF \
    -D WITH_LAPACK=ON \
    -D ENABLE_FAST_MATH=1 \
    .. 2>&1 | tee cmake.log
RUN  cd /opencv/build && make -j10 2>&1 | tee make.log && make install
RUN ln -s /usr/local/opencv3.4/lib/python3.5/dist-packages/cv2.cpython-35m-powerpc64le-linux-gnu.so /usr/lib/python3/dist-packages/cv2.so

# install chainer
RUN pip3 install Cython
RUN pip3 install cupy==2.4.0 --no-cache-dir
RUN pip3 install chainer==3.4.0 --no-cache-dir

ENTRYPOINT ["/usr/bin/s6-svscan","/etc/s6"]
CMD []
