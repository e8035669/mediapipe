#!/bin/bash

cd "${0%/*}/../"

source /opt/conda/etc/profile.d/conda.sh

echo "Build with python ${PY_VERSION}"

mamba create -y -n building -c conda-forge compilers protobuf numpy perl python=${PY_VERSION}

export CONDA_BUILD=1

conda activate building

sed -i 's/^__version__.*/__version__\ =\ "0.10.5"/g' setup.py

MEDIAPIPE_DISABLE_GPU=0 python setup.py bdist_wheel

