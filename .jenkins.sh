rm -f $WORKSPACE/*.txt
rm -f $WORKSPACE/*.log
rm -f $WORKSPACE/*.png
rm -f $WORKSPACE/*.ogv
rm -f $WORKSPACE/*.csv
rm -f $WORKSPACE/*.xml
rm -f $WORKSPACE/*.tau
rm -f $WORKSPACE/*.q
rm -f $WORKSPACE/*.qRef
rm -f $WORKSPACE/core*.bz2

upload() {
    wget -q -O $WORKSPACE/console.log $BUILD_URL/consoleText || true
    bash -e ./upload.sh || true
    awk -F, '{print $2"\t"$3"\t"}' $WORKSPACE/artifacts.txt > $WORKSPACE/artifacts_email.txt
    awk -F, '{print $2"\t"$3"\t"}' $WORKSPACE/uploads.txt > $WORKSPACE/uploads_email.txt
}

trap upload EXIT

sudo apt-get update || true #ignore checksum error
sudo apt-get -y install lsb-release git wget

DRCUTIL_UPDATED=0
CURRENT_REVISION=`git rev-parse HEAD`
if [ -e $WORKSPACE/drcutil.rev ];then
    LAST_REVISION=$(cat $WORKSPACE/drcutil.rev)
    if [ "$CURRENT_REVISION" != "$LAST_REVISION" ];then
	DRCUTIL_UPDATED=1
    fi
fi
echo $CURRENT_REVISION > $WORKSPACE/drcutil.rev
echo "`hostname`(`lsb_release -ds`)" > $WORKSPACE/env.txt

cp config.sh.jenkins config.sh
if [ "$1" = "build" ]; then
    sed -i -e "s/HOME/WORKSPACE/g" config.sh
    sed -i -e "s/Release/Debug/g" config.sh
else
    sed -i -e "s/Release/RelWithDebInfo/g" config.sh
    if [ `hostname` != "slave3" ]; then
	sed -i -e "s/MAKE_THREADS_NUMBER=2/MAKE_THREADS_NUMBER=4/g" config.sh
    fi
fi

source config.sh

if [ -e $SRC_DIR ]; then
    rm -f $SRC_DIR/*.diff
    bash -e ./diff.sh
    cat $SRC_DIR/*.diff > $WORKSPACE/changes.txt
else
    echo -n > $WORKSPACE/changes.txt
fi
awk -F, '{print $1"\t"$3"\t"}' $WORKSPACE/changes.txt > $WORKSPACE/changes_email.txt

if [ "$1" = "build" ]; then
    rm -fr $SRC_DIR
    rm -fr $PREFIX
fi

source .bashrc

if [ ! -e $SRC_DIR ] || [ $DRCUTIL_UPDATED == 1 ]; then #install from scratch
    sudo apt-get -y install python-pip python-dev
    sudo pip install google-api-python-client
    # for add-apt-repository
    if [ "$INTERNAL_MACHINE" -eq 0 ]; then
	sudo apt-get -y install software-properties-common
	if [ -z "$DISPLAY" ]; then
	    sudo apt-get -y install lcov
	    sudo sed -i -e 's/lcov_branch_coverage = 0/lcov_branch_coverage = 1/g' /etc/lcovrc
	    sudo pip install lcov_cobertura
	    sudo apt-get -y install cppcheck
	else
	    sudo apt-get -y install xautomation imagemagick recordmydesktop
	fi
    else
	sudo apt-get -y install python-software-properties
    fi
    mkdir -p $SRC_DIR
    bash -e ./getsource.sh
    sed -i -e 's/exit 1/exit 0/g' $SRC_DIR/openhrp3/util/installPackages.sh
    sed -i -e "s/openrtm-aist-dev/#openrtm-aist-dev/g" $SRC_DIR/openhrp3/util/packages.list.$DIST_KIND.$DIST_VER
    if [ -s $WORKSPACE/changes.txt ]; then
	bash -e ./checkout.sh
    fi
    bash -e ./setupenv.sh
    mkdir -p $PREFIX
    bash -e ./install.sh
else #update
    if [ -s $WORKSPACE/changes.txt ]; then
	bash -e ./checkout.sh
	VERBOSE=1 bash -e ./build.sh
    fi
fi

if [ "$INTERNAL_MACHINE" -eq 0 ]; then
    if [ -z "$DISPLAY" ]; then
    rm -f $SRC_DIR/*/build/Testing/*/Test.xml
    bash -e ./test.sh
    bash -e ./coverage.sh
    bash -e ./inspection.sh
    fi
fi

if [ "$1" = "task" ]; then
if [ "$INTERNAL_MACHINE" -eq 0 ]; then
if [ -n "$DISPLAY" ]; then
    mkdir -p $HOME/.config/Choreonoid
    cp $WORKSPACE/drcutil/.config/Choreonoid.conf $HOME/.config/Choreonoid
    sed -i -e "s/vagrant\/src/$USER\/src/g" $HOME/.config/Choreonoid/Choreonoid.conf
    sed -i -e "s/vagrant\/openrtp/$USER\/openrtp/g" $HOME/.config/Choreonoid/Choreonoid.conf
    bash -e ./task.sh $2 $3 $4 $5 $6 $7 $8 $9 ${10}
fi
fi
fi
