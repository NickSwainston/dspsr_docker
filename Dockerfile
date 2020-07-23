FROM ubuntu:18.04

# Install dependencies
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository universe && \
    apt-get update && \
    apt-get --no-install-recommends -y install \
    build-essential \
    autoconf \
    autotools-dev \
    automake \
    autogen \
    libtool \
    pkg-config \ 
    cmake \
    csh \
    g++ \
    gcc \
    gfortran \
    wget \
    git \
    expect \	
    libcfitsio-dev \
    pgplot5 \
    #swig2.0 \
    hwloc \
    python \
    python-dev \
    python-pip \
    libfftw3-3 \
    libfftw3-bin \
    libfftw3-dev \
    libfftw3-single3 \
    libx11-dev \
    libpcre3 \
    libpcre3-dev \
    #libpng12-dev \
    libpnglite-dev \   
    #libhdf5-10 \
    #libhdf5-cpp-11 \
    libhdf5-dev \
    libhdf5-serial-dev \
    libxml2 \
    libxml2-dev \
    libltdl-dev \
    gsl-bin \
    libgsl-dev \
    #libgsl2 \
    openssh-server \
    docker.io \
    xorg \
    openbox \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get -y clean

# Install python packages
RUN pip install pip -U && \
    pip install setuptools -U && \
    pip install numpy -U && \
    pip install scipy -U && \
    pip install matplotlib -U

# Create psr user which will be used to run commands with reduced privileges.
RUN adduser --disabled-password --gecos 'unprivileged user' psr && \
    echo "psr:psr" | chpasswd && \
    mkdir -p /home/psr/.ssh && \
    chown -R psr:psr /home/psr/.ssh

# PGPLOT
ENV PGPLOT_DIR /usr/lib/pgplot5
ENV PGPLOT_FONT /usr/lib/pgplot5/grfont.dat
ENV PGPLOT_INCLUDES /usr/include
ENV PGPLOT_BACKGROUND white
ENV PGPLOT_FOREGROUND black
ENV PGPLOT_DEV /xs

USER psr

# Define home, psrhome, OSTYPE and create the directory
ENV HOME /home/psr
ENV PSRHOME $HOME/software
ENV OSTYPE linux
RUN mkdir -p $PSRHOME
WORKDIR $PSRHOME

# Pull all repos
RUN wget http://www.atnf.csiro.au/people/pulsar/psrcat/downloads/psrcat_pkg.tar.gz && \
    tar -xvf psrcat_pkg.tar.gz -C $PSRHOME && \
    wget https://www.imcce.fr/content/medias/recherche/equipes/asd/calceph/calceph-3.4.5.tar.gz && \
    #wget http://www.imcce.fr/fr/presentation/equipes/ASD/inpop/calceph/calceph-2.3.0.tar.gz && \
    tar -xvf calceph-3.4.5.tar.gz -C $PSRHOME && \
    git clone https://bitbucket.org/psrsoft/tempo2.git && \
    git clone git://git.code.sf.net/p/dspsr/code dspsr && \
    git clone git://git.code.sf.net/p/psrchive/code psrchive && \
    git clone https://github.com/SixByNine/psrxml.git && \
    git clone https://github.com/nextgen-astrodata/DAL.git && \
    wget https://sourceforge.net/projects/swig/files/swig/swig-4.0.2/swig-4.0.2.tar.gz && \
    tar -xvf swig-4.0.2.tar.gz -C $PSRHOME && \
    git clone git://git.code.sf.net/p/psrdada/code psrdada

# swig
ENV SWIG_DIR $PSRHOME/swig 
ENV SWIG_PATH $SWIG_DIR/bin
ENV PATH=$SWIG_PATH:$PATH
ENV SWIG_EXECUTABLE $SWIG_DIR/bin/swig
ENV SWIG $SWIG_EXECUTABLE
WORKDIR $PSRHOME/swig-4.0.2
RUN ./configure --prefix=$SWIG_DIR && \
    make && \
    make install

# calceph
ENV CALCEPH $PSRHOME/calceph-3.4.5
ENV PATH $PATH:$CALCEPH/install/bin
ENV LD_LIBRARY_PATH $CALCEPH/install/lib
ENV C_INCLUDE_PATH $C_INCLUDE_PATH:$CALCEPH/install/include
WORKDIR $CALCEPH
RUN ./configure --prefix=$CALCEPH/install --with-pic --enable-shared --enable-static --enable-fortran --enable-thread && \
    make && \
    make check && \
    make install && \
    rm -f ../calceph-2.3.0.tar.gz

# DAL
ENV DAL $PSRHOME/DAL
ENV PATH $PATH:$DAL/install/bin
ENV C_INCLUDE_PATH $C_INCLUDE_PATH:$DAL/install/include
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:$DAL/install/lib
WORKDIR $DAL
RUN mkdir build
WORKDIR $DAL/build
RUN cmake .. -DCMAKE_INSTALL_PREFIX=$DAL/install && \
    make -j $(nproc) && \
    make && \
    make install

# Psrcat
ENV PSRCAT_FILE $PSRHOME/psrcat_tar/psrcat.db
ENV PATH $PATH:$PSRHOME/psrcat_tar
WORKDIR $PSRHOME/psrcat_tar
RUN /bin/bash makeit && \
    rm -f ../psrcat_pkg.tar.gz

# PSRXML
ENV PSRXML $PSRHOME/psrxml
ENV PATH $PATH:$PSRXML/install/bin
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:$PSRXML/install/lib
ENV C_INCLUDE_PATH $C_INCLUDE_PATH:$PSRXML/install/include
WORKDIR $PSRXML
RUN autoreconf --install --warnings=none
RUN ./configure --prefix=$PSRXML/install && \
    make && \
    make install && \
    rm -rf .git

# tempo2
ENV TEMPO2 $PSRHOME/tempo2/T2runtime
ENV PATH $PATH:$PSRHOME/tempo2/T2runtime/bin
ENV C_INCLUDE_PATH $C_INCLUDE_PATH:$PSRHOME/tempo2/T2runtime/include
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:$PSRHOME/tempo2/T2runtime/lib
WORKDIR $PSRHOME/tempo2
RUN sync && perl -pi -e 's/chmod \+x/#chmod +x/' bootstrap # Get rid of: returned a non-zero code: 126.
RUN ./bootstrap && \
    ./configure --x-libraries=/usr/lib/x86_64-linux-gnu --with-calceph=$CALCEPH/install/lib --enable-shared --enable-static --with-pic F77=gfortran CPPFLAGS="-I"$CALCEPH"/install/include" && \
    make -j $(nproc) && \
    make install && \
    make plugins-install && \
    rm -rf .git

# PSRCHIVE
ENV PSRCHIVE $PSRHOME/psrchive
ENV PATH $PATH:$PSRCHIVE/install/bin
ENV C_INCLUDE_PATH $C_INCLUDE_PATH:$PSRCHIVE/install/include
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:$PSRCHIVE/install/lib
ENV PYTHONPATH $PSRCHIVE/install/lib/python2.7/site-packages
WORKDIR $PSRCHIVE
RUN ./bootstrap && \
    ./configure --prefix=$PSRCHIVE/install --x-libraries=/usr/lib/x86_64-linux-gnu --with-psrxml-dir=$PSRXML/install --enable-shared --enable-static F77=gfortran LDFLAGS="-L"$PSRXML"/install/lib" LIBS="-lpsrxml -lxml2" && \
    make -j $(nproc) && \
    make && \
    make install && \
    rm -rf .git
WORKDIR $HOME
RUN echo "Predictor::default = tempo2" >> .psrchive.cfg && \
    echo "Predictor::policy = default" >> .psrchive.cfg

# PSRDADA
ENV PSRDADA_HOME $PSRHOME/psrdada
WORKDIR $PSRDADA_HOME
RUN mkdir build/ && \
    ./bootstrap && \
    ./configure --prefix=$PSRDADA_HOME/build && \
    #sed -i "9 a #ifndef UINT64_C\n#define UINT64_C(c) (c ## ULL)\n#endif" bpsr/src/bpsr_udp.h && \
    make && \
    make install && \
    make clean 
ENV PATH $PATH:$PSRDADA_HOME/build/bin
ENV PSRDADA_BUILD $PSRDADA_HOME/build/
ENV PACKAGES $PSRDADA_BUILD

# DSPSR
ENV DSPSR $PSRHOME/dspsr
ENV PATH $PATH:$DSPSR/install/bin
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:$DSPSR/install/lib
ENV C_INCLUDE_PATH $C_INCLUDE_PATH:$DSPSR/install/include
WORKDIR $DSPSR
RUN ./bootstrap && \
    echo "apsr asp bcpm bpsr cpsr cpsr2 gmrt sigproc vdif fits" > backends.list && \
    ./configure --prefix=$DSPSR/install --with-psrdada-dir=$PSRDADA_BUILD --x-libraries=/usr/lib/x86_64-linux-gnu CPPFLAGS="-I"$DAL"/install/include -I/usr/include/hdf5/serial -I"$PSRXML"/install/include" LDFLAGS="-L"$DAL"/install/lib -L/usr/lib/x86_64-linux-gnu/hdf5/serial -L"$PSRXML"/install/lib" LIBS="-lpgplot -lcpgplot -lpsrxml -lxml2" && \
    make -j $(nproc) && \
    make && \
    make install

RUN env | awk '{print "export ",$0}' >> $HOME/.profile
WORKDIR $HOME
USER root
