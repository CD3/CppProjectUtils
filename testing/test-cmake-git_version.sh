#! /bin/bash



set -e

TOPDIR=$(readlink -f $0.d)
rm ${TOPDIR} -rf
mkdir ${TOPDIR}

cd ${TOPDIR}

cat << EOF > CMakeLists.txt
cmake_minimum_required(VERSION 3.1)

include( ${TOPDIR}/../../cmake/Modules/macro-git_version.cmake )

git_version(test)
message( STATUS "version: \${test_VERSION}" )
project( test VERSION \${test_VERSION} )

EOF

export GIT_DIR=$PWD/.git

mkdir build
cd build
#cmake .. 2>&1 | grep "Source directory is not a git repo."
cd ..
rm build -r

git init
git add .

git commit -m "initial commit"
git tag 1.0
mkdir build
cd build
cmake ..

cd ..
rm build -r
touch tmp1.txt
git add .
git commit -m "update"
git tag 1.0.1
mkdir build
cd build
cmake ..


exit 0
